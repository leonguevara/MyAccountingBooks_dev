CREATE TABLE IF NOT EXISTS enum_label (
  enum_name text NOT NULL,   -- 'AccountKind' or 'AccountRole'
  enum_value int NOT NULL,   -- numeric value
  locale text NOT NULL,      -- 'es-MX', 'en-US'
  label text NOT NULL,
  description text NULL,
  PRIMARY KEY (enum_name, enum_value, locale)
);
