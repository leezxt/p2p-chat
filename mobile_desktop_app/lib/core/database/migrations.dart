/// 資料庫 migration 定義（規格 §26 規則 14：migration 必須可追蹤）。
///
/// 每個版本對應一組 SQL。升級時依序執行 version N+1..target 的語句。
/// 新增資料表 / 欄位一律新增 migration，不修改既有已發佈 migration。
class Migration {
  const Migration(this.version, this.statements);
  final int version;
  final List<String> statements;
}

/// 目前 schema 版本。每次新增 migration 時 +1。
const int kCurrentDbVersion = 7;

/// 依版本排序的 migration 清單。
const List<Migration> kMigrations = [
  Migration(1, [
    // 會話（規格 §20）
    '''
    CREATE TABLE chat_conversations (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      peer_user_id TEXT,
      last_message_preview TEXT,
      last_message_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
    // 訊息（規格 §20.1）
    '''
    CREATE TABLE chat_messages (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      sender_user_id TEXT NOT NULL,
      sender_device_id TEXT NOT NULL,
      type TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      schema_version INTEGER NOT NULL DEFAULT 1
    )
    ''',
    // 依會話 + 時間查詢最近 N 則（規格 §21：載入最近 50 則）
    'CREATE INDEX idx_messages_conv_created '
        'ON chat_messages (conversation_id, created_at DESC)',
  ]),
  Migration(2, [
    '''
    CREATE TABLE local_identities (
      user_id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE devices (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      public_key TEXT,
      public_key_fingerprint TEXT,
      is_local INTEGER NOT NULL DEFAULT 0 CHECK (is_local IN (0, 1)),
      revoked_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE (user_id, public_key_fingerprint)
    )
    ''',
    'CREATE INDEX idx_devices_user_id ON devices (user_id)',
    '''
    CREATE TABLE contacts (
      user_id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      device_id TEXT,
      public_key TEXT,
      public_key_fingerprint TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_contacts_display_name ON contacts (display_name)',
  ]),
  Migration(3, [
    '''
    CREATE TABLE crypto_replay_records (
      sender_device_id TEXT NOT NULL,
      message_id TEXT NOT NULL,
      nonce TEXT NOT NULL,
      received_at INTEGER NOT NULL,
      PRIMARY KEY (sender_device_id, message_id),
      UNIQUE (sender_device_id, nonce)
    )
    ''',
    'CREATE INDEX idx_crypto_replay_received_at '
        'ON crypto_replay_records (received_at)',
  ]),
  Migration(4, [
    '''
    CREATE TABLE remote_key_trust (
      device_id TEXT PRIMARY KEY,
      trusted_public_key TEXT NOT NULL,
      trusted_fingerprint TEXT NOT NULL,
      pending_public_key TEXT,
      pending_fingerprint TEXT,
      changed_at INTEGER,
      trusted_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
    '''
    INSERT INTO remote_key_trust (
      device_id,
      trusted_public_key,
      trusted_fingerprint,
      trusted_at,
      updated_at
    )
    SELECT
      device_id,
      public_key,
      public_key_fingerprint,
      updated_at,
      updated_at
    FROM contacts
    WHERE device_id IS NOT NULL
      AND public_key IS NOT NULL
      AND public_key_fingerprint IS NOT NULL
    ''',
  ]),
  Migration(5, [
    '''
    CREATE TABLE mailbox_pending_queue (
      id TEXT PRIMARY KEY,
      message_id TEXT NOT NULL UNIQUE,
      recipient_device_id TEXT NOT NULL,
      encrypted_envelope_json TEXT NOT NULL,
      state TEXT NOT NULL CHECK (state IN ('PENDING', 'IN_FLIGHT', 'FAILED')),
      attempt_count INTEGER NOT NULL DEFAULT 0,
      next_attempt_at INTEGER NOT NULL,
      lease_until INTEGER,
      last_error_code TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_mailbox_pending_due '
        'ON mailbox_pending_queue (state, next_attempt_at)',
  ]),
  Migration(6, [
    '''
    CREATE TABLE mailbox_receipts (
      message_id TEXT PRIMARY KEY,
      mailbox_message_id TEXT NOT NULL UNIQUE,
      acknowledging_device_id TEXT NOT NULL,
      ack_status TEXT NOT NULL CHECK (ack_status IN ('DELIVERED', 'READ')),
      updated_at INTEGER NOT NULL
    )
    ''',
  ]),
  Migration(7, [
    '''
    CREATE TABLE app_settings (
      setting_key TEXT PRIMARY KEY,
      setting_value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
  ]),
];
