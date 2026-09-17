import express from 'express';
import cors from 'cors';
import { pool, migrate } from './db.js';
import { generateToken, generateJoinCode, requireAuth } from './auth.js';
import { memberView, taskView } from './memberView.js';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true }));

// --- Groups -----------------------------------------------------------

app.post('/groups', async (req, res) => {
  const { name, displayName } = req.body ?? {};
  if (!name?.trim() || !displayName?.trim()) {
    return res.status(400).json({ error: 'name and displayName are required' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const joinCode = generateJoinCode();
    const { rows: groupRows } = await client.query(
      'INSERT INTO groups (name, join_code) VALUES ($1, $2) RETURNING *',
      [name.trim(), joinCode],
    );
    const group = groupRows[0];

    const token = generateToken();
    const { rows: memberRows } = await client.query(
      `INSERT INTO members (group_id, display_name, token, is_owner)
       VALUES ($1, $2, $3, true) RETURNING *`,
      [group.id, displayName.trim(), token],
    );
    await client.query('COMMIT');

    res.status(201).json({
      group: { id: group.id, name: group.name, joinCode: group.join_code },
      member: memberView(memberRows[0]),
      token,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

app.post('/groups/join', async (req, res) => {
  const { joinCode, displayName } = req.body ?? {};
  if (!joinCode?.trim() || !displayName?.trim()) {
    return res.status(400).json({ error: 'joinCode and displayName are required' });
  }

  const { rows: groupRows } = await pool.query(
    'SELECT * FROM groups WHERE join_code = $1',
    [joinCode.trim().toUpperCase()],
  );
  const group = groupRows[0];
  if (!group) {
    return res.status(404).json({ error: 'No group with that code' });
  }

  const token = generateToken();
  const { rows: memberRows } = await pool.query(
    `INSERT INTO members (group_id, display_name, token, is_owner)
     VALUES ($1, $2, $3, false) RETURNING *`,
    [group.id, displayName.trim(), token],
  );

  res.status(201).json({
    group: { id: group.id, name: group.name, joinCode: group.join_code },
    member: memberView(memberRows[0]),
    token,
  });
});

app.get('/groups/mine', requireAuth, async (req, res) => {
  const { rows: groupRows } = await pool.query(
    'SELECT * FROM groups WHERE id = $1',
    [req.member.group_id],
  );
  const { rows: memberRows } = await pool.query(
    'SELECT * FROM members WHERE group_id = $1 ORDER BY created_at',
    [req.member.group_id],
  );

  res.json({
    group: {
      id: groupRows[0].id,
      name: groupRows[0].name,
      joinCode: groupRows[0].join_code,
    },
    me: memberView(req.member),
    members: memberRows.map(memberView),
  });
});

// --- Tasks --------------------------------------------------------------

app.post('/tasks', requireAuth, async (req, res) => {
  if (!req.member.is_owner) {
    return res.status(403).json({ error: 'Only the group owner can assign tasks' });
  }

  const {
    assigneeMemberId,
    title,
    frequency,
    morningHour = 8,
    morningMinute = 0,
    confirmationCode,
  } = req.body ?? {};

  if (!assigneeMemberId || !title?.trim() || !frequency) {
    return res
      .status(400)
      .json({ error: 'assigneeMemberId, title and frequency are required' });
  }
  if (!['hourly', 'daily', 'weekly', 'morningAndNight'].includes(frequency)) {
    return res.status(400).json({ error: 'Invalid frequency' });
  }

  const { rows: assigneeRows } = await pool.query(
    'SELECT * FROM members WHERE id = $1 AND group_id = $2',
    [assigneeMemberId, req.member.group_id],
  );
  if (!assigneeRows[0]) {
    return res.status(404).json({ error: 'Assignee not found in this group' });
  }

  const { rows } = await pool.query(
    `INSERT INTO tasks
       (group_id, assignee_member_id, created_by_member_id, title, frequency,
        morning_hour, morning_minute, confirmation_code)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
    [
      req.member.group_id,
      assigneeMemberId,
      req.member.id,
      title.trim(),
      frequency,
      morningHour,
      morningMinute,
      confirmationCode?.trim() || null,
    ],
  );

  res.status(201).json({ task: taskView(rows[0]) });
});

app.get('/tasks/mine', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM tasks WHERE assignee_member_id = $1 ORDER BY created_at',
    [req.member.id],
  );
  res.json({ tasks: rows.map(taskView) });
});

app.get('/tasks/assigned-by-me', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM tasks WHERE created_by_member_id = $1 ORDER BY created_at',
    [req.member.id],
  );
  res.json({ tasks: rows.map(taskView) });
});

app.post('/tasks/:id/complete', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM tasks WHERE id = $1 AND assignee_member_id = $2',
    [req.params.id, req.member.id],
  );
  const task = rows[0];
  if (!task) {
    return res.status(404).json({ error: 'Task not found' });
  }

  if (task.confirmation_code) {
    const { code } = req.body ?? {};
    if (code !== task.confirmation_code) {
      return res.status(403).json({ error: 'Incorrect confirmation code' });
    }
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: updatedTaskRows } = await client.query(
      `UPDATE tasks SET active = false, last_completed_at = now()
       WHERE id = $1 RETURNING *`,
      [task.id],
    );

    const { rows: memberRows } = await client.query(
      'SELECT * FROM members WHERE id = $1 FOR UPDATE',
      [req.member.id],
    );
    const member = memberRows[0];

    const today = new Date().toISOString().slice(0, 10);
    let streak = member.current_streak;
    if (!member.last_completion_date) {
      streak = 1;
    } else {
      const last = new Date(member.last_completion_date);
      const diffDays = Math.round(
        (new Date(today) - last) / (1000 * 60 * 60 * 24),
      );
      if (diffDays === 0) {
        // already completed something today, streak unchanged
      } else if (diffDays === 1) {
        streak += 1;
      } else {
        streak = 1;
      }
    }

    const { rows: updatedMemberRows } = await client.query(
      `UPDATE members
       SET total_points = total_points + 10,
           current_streak = $1,
           last_completion_date = $2
       WHERE id = $3 RETURNING *`,
      [streak, today, member.id],
    );

    await client.query('COMMIT');
    res.json({
      task: taskView(updatedTaskRows[0]),
      me: memberView(updatedMemberRows[0]),
    });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

app.post('/tasks/:id/reactivate', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    `UPDATE tasks SET active = true
     WHERE id = $1 AND (assignee_member_id = $2 OR created_by_member_id = $2)
     RETURNING *`,
    [req.params.id, req.member.id],
  );
  if (!rows[0]) {
    return res.status(404).json({ error: 'Task not found' });
  }
  res.json({ task: taskView(rows[0]) });
});

app.delete('/tasks/:id', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    'DELETE FROM tasks WHERE id = $1 AND created_by_member_id = $2 RETURNING id',
    [req.params.id, req.member.id],
  );
  if (!rows[0]) {
    return res.status(404).json({ error: 'Task not found or not yours to delete' });
  }
  res.status(204).end();
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const port = process.env.PORT || 3000;
migrate()
  .then(() => {
    app.listen(port, () => console.log(`Server listening on port ${port}`));
  })
  .catch((err) => {
    console.error('Failed to run migrations', err);
    process.exit(1);
  });
