import crypto from 'node:crypto';
import { pool } from './db.js';

export function generateToken() {
  return crypto.randomBytes(24).toString('hex');
}

export function generateJoinCode() {
  return crypto.randomBytes(4).toString('hex').toUpperCase();
}

export async function requireAuth(req, res, next) {
  const header = req.header('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }

  const { rows } = await pool.query(
    'SELECT * FROM members WHERE token = $1',
    [token],
  );
  const member = rows[0];
  if (!member) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  req.member = member;
  next();
}
