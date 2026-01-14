import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { bearerAuth } from 'hono/bearer-auth';

type Bindings = {
  DB: D1Database;
  API_TOKEN: string;
  ENVIRONMENT: string;
};

const app = new Hono<{ Bindings: Bindings }>();

// CORS for dashboard access
app.use('/*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// Public endpoints (no auth required)
app.get('/', (c) => c.text('Dev Tracker API'));
app.get('/api/health', async (c) => {
  try {
    await c.env.DB.prepare('SELECT 1').first();
    return c.json({
      status: 'healthy',
      database: 'connected',
      environment: c.env.ENVIRONMENT,
    });
  } catch (e) {
    return c.json({ status: 'unhealthy', error: String(e) }, 500);
  }
});

// Auth middleware for write operations
const authMiddleware = async (c: any, next: any) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Missing authorization' }, 401);
  }
  const token = authHeader.slice(7);
  if (token !== c.env.API_TOKEN) {
    return c.json({ error: 'Invalid token' }, 403);
  }
  await next();
};

// ============================================
// SESSION ENDPOINTS
// ============================================

app.post('/api/sessions/start', authMiddleware, async (c) => {
  const body = await c.req.json();
  const { session_id, repo_path, project_api_key, started_at } = body;

  if (!session_id || !started_at) {
    return c.json({ error: 'session_id and started_at required' }, 400);
  }

  await c.env.DB.prepare(`
    INSERT OR REPLACE INTO sessions (session_id, repo_path, project_api_key, started_at, status)
    VALUES (?, ?, ?, ?, 'active')
  `).bind(session_id, repo_path, project_api_key, started_at).run();

  return c.json({ success: true, session_id });
});

app.post('/api/sessions/end', authMiddleware, async (c) => {
  const body = await c.req.json();
  const { session_id, ended_at, total_tool_calls } = body;

  if (!session_id) {
    return c.json({ error: 'session_id required' }, 400);
  }

  await c.env.DB.prepare(`
    UPDATE sessions
    SET ended_at = ?, total_tool_calls = ?, status = 'completed'
    WHERE session_id = ?
  `).bind(ended_at, total_tool_calls || 0, session_id).run();

  // Update daily summary
  const session = await c.env.DB.prepare(`
    SELECT * FROM sessions WHERE session_id = ?
  `).bind(session_id).first();

  if (session && session.started_at && session.ended_at) {
    const date = new Date((session.started_at as number) * 1000).toISOString().split('T')[0];
    const hours = ((session.ended_at as number) - (session.started_at as number)) / 3600;

    await c.env.DB.prepare(`
      INSERT INTO daily_summaries (date, repo_path, project_api_key, total_sessions, total_dev_hours)
      VALUES (?, ?, ?, 1, ?)
      ON CONFLICT(date, repo_path, user_id) DO UPDATE SET
        total_sessions = total_sessions + 1,
        total_dev_hours = total_dev_hours + excluded.total_dev_hours
    `).bind(date, session.repo_path, session.project_api_key, hours).run();
  }

  return c.json({ success: true });
});

// ============================================
// TOOL EVENTS
// ============================================

app.post('/api/events', authMiddleware, async (c) => {
  const body = await c.req.json();
  const { session_id, tool_name, event_type, exit_code, timestamp, metadata } = body;

  if (!session_id || !tool_name || !event_type || !timestamp) {
    return c.json({ error: 'session_id, tool_name, event_type, timestamp required' }, 400);
  }

  await c.env.DB.prepare(`
    INSERT INTO tool_events (session_id, tool_name, event_type, exit_code, timestamp, metadata)
    VALUES (?, ?, ?, ?, ?, ?)
  `).bind(session_id, tool_name, event_type, exit_code, timestamp, metadata ? JSON.stringify(metadata) : null).run();

  // Update tool call count on session
  if (event_type === 'start') {
    await c.env.DB.prepare(`
      UPDATE sessions SET total_tool_calls = total_tool_calls + 1 WHERE session_id = ?
    `).bind(session_id).run();
  }

  return c.json({ success: true });
});

// ============================================
// COMMITS
// ============================================

app.post('/api/commits', authMiddleware, async (c) => {
  const body = await c.req.json();
  const { commit_hash, repo_path, session_id, message, author, timestamp, files_changed, insertions, deletions, branch } = body;

  if (!commit_hash || !repo_path || !timestamp) {
    return c.json({ error: 'commit_hash, repo_path, timestamp required' }, 400);
  }

  // Get project mapping
  const mapping = await c.env.DB.prepare(`
    SELECT project_api_key FROM project_mappings WHERE repo_path = ?
  `).bind(repo_path).first();

  await c.env.DB.prepare(`
    INSERT OR IGNORE INTO commits
    (commit_hash, repo_path, session_id, project_api_key, message, author, timestamp, files_changed, insertions, deletions, branch)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    commit_hash, repo_path, session_id,
    mapping?.project_api_key || null,
    message, author, timestamp, files_changed, insertions, deletions, branch
  ).run();

  // Update daily summary
  const date = new Date(timestamp * 1000).toISOString().split('T')[0];
  await c.env.DB.prepare(`
    INSERT INTO daily_summaries (date, repo_path, project_api_key, total_commits, total_insertions, total_deletions)
    VALUES (?, ?, ?, 1, ?, ?)
    ON CONFLICT(date, repo_path, user_id) DO UPDATE SET
      total_commits = total_commits + 1,
      total_insertions = total_insertions + excluded.total_insertions,
      total_deletions = total_deletions + excluded.total_deletions
  `).bind(date, repo_path, mapping?.project_api_key || null, insertions || 0, deletions || 0).run();

  return c.json({ success: true, commit_hash });
});

// ============================================
// PROJECT MAPPINGS
// ============================================

app.get('/api/mappings', async (c) => {
  const result = await c.env.DB.prepare(`
    SELECT * FROM project_mappings ORDER BY project_name
  `).all();
  return c.json(result.results);
});

app.post('/api/mappings', authMiddleware, async (c) => {
  const body = await c.req.json();
  const { repo_path, project_api_key, project_name, phase } = body;

  if (!repo_path || !project_api_key) {
    return c.json({ error: 'repo_path and project_api_key required' }, 400);
  }

  await c.env.DB.prepare(`
    INSERT OR REPLACE INTO project_mappings (repo_path, project_api_key, project_name, phase)
    VALUES (?, ?, ?, ?)
  `).bind(repo_path, project_api_key, project_name, phase || 'development').run();

  return c.json({ success: true });
});

// ============================================
// DASHBOARD DATA
// ============================================

app.get('/api/data', async (c) => {
  const days = parseInt(c.req.query('days') || '30');
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);
  const cutoffDate = cutoff.toISOString().split('T')[0];

  // Get summary totals
  const summary = await c.env.DB.prepare(`
    SELECT
      COALESCE(SUM(total_dev_hours), 0) as total_dev_hours,
      COALESCE(SUM(total_commits), 0) as total_commits,
      COALESCE(SUM(total_insertions), 0) as total_lines_added,
      COALESCE(SUM(total_deletions), 0) as total_lines_deleted
    FROM daily_summaries
    WHERE date >= ?
  `).bind(cutoffDate).first();

  // Get daily activity
  const dailyActivity = await c.env.DB.prepare(`
    SELECT
      date,
      SUM(total_dev_hours) as hours,
      SUM(active_coding_hours) as active_hours,
      SUM(total_commits) as commits,
      SUM(total_insertions + total_deletions) as lines_changed
    FROM daily_summaries
    WHERE date >= ?
    GROUP BY date
    ORDER BY date DESC
  `).bind(cutoffDate).all();

  // Get recent commits
  const recentCommits = await c.env.DB.prepare(`
    SELECT
      c.commit_hash as hash,
      c.repo_path,
      REPLACE(c.repo_path, '/Users/' || SUBSTR(c.repo_path, 8, INSTR(SUBSTR(c.repo_path, 8), '/') - 1) || '/', '') as repo,
      c.message,
      c.timestamp,
      c.insertions as additions,
      c.deletions,
      c.pushed_to_roadmap as synced_to_roadmap,
      pm.project_name
    FROM commits c
    LEFT JOIN project_mappings pm ON c.repo_path = pm.repo_path
    WHERE c.timestamp >= ?
    ORDER BY c.timestamp DESC
    LIMIT 50
  `).bind(Math.floor(cutoff.getTime() / 1000)).all();

  // Get project mappings
  const mappings = await c.env.DB.prepare(`
    SELECT repo_path, project_name, project_api_key, phase, auto_push_updates as auto_push
    FROM project_mappings
  `).all();

  // Calculate ROI
  const devHours = (summary?.total_dev_hours as number) || 0;
  const multiplier = 2.5;
  const hourlyRate = 75;
  const timeSaved = devHours * (multiplier - 1);
  const costSavings = timeSaved * hourlyRate;

  return c.json({
    generated_at: new Date().toISOString(),
    data_mode: 'live',
    period_days: days,
    summary: {
      total_dev_hours: devHours,
      total_commits: summary?.total_commits || 0,
      total_lines_added: summary?.total_lines_added || 0,
      total_lines_deleted: summary?.total_lines_deleted || 0,
      time_saved_hours: timeSaved,
      cost_savings: costSavings,
    },
    roi_calculation: {
      dev_hours: devHours,
      multiplier,
      estimated_manual_hours: devHours * multiplier,
      time_saved: timeSaved,
      hourly_rate: hourlyRate,
      cost_savings: costSavings,
    },
    daily_activity: dailyActivity.results,
    recent_commits: recentCommits.results.map((c: any) => ({
      ...c,
      synced_to_roadmap: c.synced_to_roadmap === 1,
    })),
    project_mappings: mappings.results,
  });
});

// ============================================
// CSV EXPORT
// ============================================

app.get('/api/export/csv', async (c) => {
  const days = parseInt(c.req.query('days') || '30');
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);
  const cutoffDate = cutoff.toISOString().split('T')[0];

  const rows = await c.env.DB.prepare(`
    SELECT
      ds.date,
      COALESCE(pm.project_name, 'Unlinked') as project_name,
      COALESCE(pm.phase, 'unknown') as phase,
      ds.total_dev_hours as hours,
      ds.total_commits as commits,
      ds.total_insertions as additions,
      ds.total_deletions as deletions,
      CASE WHEN pm.phase IN ('development', 'beta') THEN 'Yes' ELSE 'No' END as capitalizable
    FROM daily_summaries ds
    LEFT JOIN project_mappings pm ON ds.repo_path = pm.repo_path
    WHERE ds.date >= ?
    ORDER BY ds.date DESC, pm.project_name
  `).bind(cutoffDate).all();

  // Build CSV
  let csv = 'Date,Project,Phase,Hours,Commits,Lines Added,Lines Deleted,Capitalizable\n';

  let totalHours = 0, totalCommits = 0, totalAdd = 0, totalDel = 0, capHours = 0;

  for (const row of rows.results as any[]) {
    csv += `${row.date},${row.project_name},${row.phase},${(row.hours || 0).toFixed(2)},${row.commits || 0},${row.additions || 0},${row.deletions || 0},${row.capitalizable}\n`;
    totalHours += row.hours || 0;
    totalCommits += row.commits || 0;
    totalAdd += row.additions || 0;
    totalDel += row.deletions || 0;
    if (row.capitalizable === 'Yes') capHours += row.hours || 0;
  }

  csv += `\nTOTALS,,,${totalHours.toFixed(2)},${totalCommits},${totalAdd},${totalDel},\n`;
  csv += `Capitalizable Hours,,,${capHours.toFixed(2)},,,,\n`;
  csv += `Expensed Hours,,,${(totalHours - capHours).toFixed(2)},,,,\n`;

  const filename = `dev-tracker-export-${new Date().toISOString().split('T')[0]}.csv`;

  return new Response(csv, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="${filename}"`,
    },
  });
});

// ============================================
// STATS ENDPOINT (for CLI)
// ============================================

app.get('/api/stats', async (c) => {
  const days = parseInt(c.req.query('days') || '7');
  const repo = c.req.query('repo');

  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);
  const cutoffDate = cutoff.toISOString().split('T')[0];

  let query = `
    SELECT
      SUM(total_dev_hours) as hours,
      SUM(total_commits) as commits,
      SUM(total_insertions + total_deletions) as lines_changed,
      COUNT(DISTINCT date) as active_days
    FROM daily_summaries
    WHERE date >= ?
  `;
  const params: any[] = [cutoffDate];

  if (repo) {
    query += ' AND repo_path LIKE ?';
    params.push(`%${repo}%`);
  }

  const stats = await c.env.DB.prepare(query).bind(...params).first();

  return c.json({
    period_days: days,
    repo_filter: repo || 'all',
    stats: {
      hours: ((stats?.hours as number) || 0).toFixed(2),
      commits: stats?.commits || 0,
      lines_changed: stats?.lines_changed || 0,
      active_days: stats?.active_days || 0,
    },
  });
});

// ============================================
// MCP JSON-RPC ENDPOINT
// ============================================

const MCP_TOOLS = [
  {
    name: 'get_dev_stats',
    description: 'Get development statistics for a time period',
    inputSchema: {
      type: 'object',
      properties: {
        days: { type: 'number', description: 'Number of days to include (default: 7)' },
        repo: { type: 'string', description: 'Filter by repo path (optional)' },
      },
    },
  },
  {
    name: 'get_recent_commits',
    description: 'Get recent commits across all tracked repos',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Number of commits to return (default: 20)' },
      },
    },
  },
  {
    name: 'link_repo_to_project',
    description: 'Link a git repository to a roadmap project',
    inputSchema: {
      type: 'object',
      properties: {
        repo_path: { type: 'string', description: 'Full path to the git repository' },
        project_api_key: { type: 'string', description: 'API key for the roadmap project' },
        project_name: { type: 'string', description: 'Display name for the project' },
        phase: { type: 'string', description: 'Project phase (ideation, development, beta, live, maintenance)' },
      },
      required: ['repo_path', 'project_api_key', 'project_name'],
    },
  },
  {
    name: 'get_linked_projects',
    description: 'Get all repos linked to roadmap projects',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'generate_summary',
    description: 'Generate an end-of-day development summary',
    inputSchema: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'Date in YYYY-MM-DD format (default: today)' },
      },
    },
  },
];

// MCP tool execution
async function executeMcpTool(db: D1Database, name: string, args: any): Promise<any> {
  switch (name) {
    case 'get_dev_stats': {
      const days = args.days || 7;
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - days);
      const cutoffDate = cutoff.toISOString().split('T')[0];

      let query = `
        SELECT
          SUM(total_dev_hours) as hours,
          SUM(total_commits) as commits,
          SUM(total_insertions + total_deletions) as lines_changed
        FROM daily_summaries WHERE date >= ?
      `;
      const params: any[] = [cutoffDate];
      if (args.repo) {
        query += ' AND repo_path LIKE ?';
        params.push(`%${args.repo}%`);
      }
      const stats = await db.prepare(query).bind(...params).first();
      return {
        period_days: days,
        hours: ((stats?.hours as number) || 0).toFixed(2),
        commits: stats?.commits || 0,
        lines_changed: stats?.lines_changed || 0,
      };
    }

    case 'get_recent_commits': {
      const limit = args.limit || 20;
      const commits = await db.prepare(`
        SELECT commit_hash, repo_path, message, timestamp, insertions, deletions
        FROM commits ORDER BY timestamp DESC LIMIT ?
      `).bind(limit).all();
      return commits.results;
    }

    case 'link_repo_to_project': {
      await db.prepare(`
        INSERT OR REPLACE INTO project_mappings (repo_path, project_api_key, project_name, phase)
        VALUES (?, ?, ?, ?)
      `).bind(args.repo_path, args.project_api_key, args.project_name, args.phase || 'development').run();
      return { success: true, message: `Linked ${args.repo_path} to ${args.project_name}` };
    }

    case 'get_linked_projects': {
      const mappings = await db.prepare('SELECT * FROM project_mappings').all();
      return mappings.results;
    }

    case 'generate_summary': {
      const date = args.date || new Date().toISOString().split('T')[0];
      const summary = await db.prepare(`
        SELECT
          ds.date,
          COALESCE(pm.project_name, 'Unlinked') as project,
          pm.phase,
          ds.total_dev_hours as hours,
          ds.total_commits as commits,
          ds.total_insertions as additions,
          ds.total_deletions as deletions,
          CASE WHEN pm.phase IN ('development', 'beta') THEN 'Yes' ELSE 'No' END as capitalizable
        FROM daily_summaries ds
        LEFT JOIN project_mappings pm ON ds.repo_path = pm.repo_path
        WHERE ds.date = ?
      `).bind(date).all();
      return { date, entries: summary.results };
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

// MCP JSON-RPC handler
app.post('/mcp', authMiddleware, async (c) => {
  const body = await c.req.json();
  const { jsonrpc, id, method, params } = body;

  if (jsonrpc !== '2.0') {
    return c.json({ jsonrpc: '2.0', id, error: { code: -32600, message: 'Invalid Request' } });
  }

  try {
    let result: any;

    switch (method) {
      case 'initialize':
        result = {
          protocolVersion: '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'dev-tracker-mcp', version: '1.0.0' },
        };
        break;

      case 'tools/list':
        result = { tools: MCP_TOOLS };
        break;

      case 'tools/call':
        const { name, arguments: args } = params;
        const toolResult = await executeMcpTool(c.env.DB, name, args || {});
        result = {
          content: [{ type: 'text', text: JSON.stringify(toolResult, null, 2) }],
        };
        break;

      default:
        return c.json({ jsonrpc: '2.0', id, error: { code: -32601, message: `Method not found: ${method}` } });
    }

    return c.json({ jsonrpc: '2.0', id, result });
  } catch (e: any) {
    return c.json({ jsonrpc: '2.0', id, error: { code: -32000, message: e.message } });
  }
});

// MCP tool list (for discovery)
app.get('/mcp/tools', (c) => c.json({ tools: MCP_TOOLS }));

export default app;
