-- 012_Populating_account_type_v3.sql
-- Seeds the AccountType catalog.
--
-- Updates vs v2:
-- - Adds more specific financial AccountTypes aligned with finer AccountRole RIF roles:
--   INTEREST_INCOME / INTEREST_EXPENSE / FX_GAIN / FX_LOSS / INFLATION_GAIN / INFLATION_LOSS
--   BANK_FEES_INCOME / BANK_FEES_EXPENSE / OTHER_FIN_INCOME / OTHER_FIN_EXPENSE
--
-- Assumptions:
-- - account_type columns: code, name, kind, normal_balance, sort_order, standard, is_active, created_at
-- - AccountKind raw values:
--     system=0, asset=1, liability=2, equity=3, income=4, costOfSales=5, expense=6, memorandum=7, statistical=8
-- - normal_balance raw values: debit=0, credit=1

BEGIN;

-- Optional: avoid duplicates if you re-run the script.
-- If you want idempotency, you can use ON CONFLICT (code) DO UPDATE,
-- but that requires a UNIQUE constraint on (code).
-- Here we do simple inserts assuming a clean seed environment.

INSERT INTO account_type
(code, name, kind, normal_balance, sort_order, standard, is_active, created_at)
VALUES
-- =========================
-- System
-- =========================
('SYSTEM','SYSTEM',0,0,0,'GEN',true,now()),
-- =========================
-- Assets
-- =========================
('CASH','Cash',1,0,10,'GEN',true,now()),
('BANK','Bank accounts',1,0,20,'GEN',true,now()),
('AR','Accounts receivable',1,0,30,'GEN',true,now()),
('INVENTORY','Inventory',1,0,40,'GEN',true,now()),
('FIXED_ASSET','Fixed assets',1,0,50,'GEN',true,now()),
('ACCUM_DEPR','Accumulated depreciation',1,1,60,'GEN',true,now()),
('PREPAID','Prepaid expenses',1,0,70,'GEN',true,now()),
('OTHER_ASSET','Other assets',1,0,80,'GEN',true,now()),

-- =========================
-- Liabilities
-- =========================
('AP','Accounts payable',2,1,110,'GEN',true,now()),
('TAX_PAYABLE','Taxes payable',2,1,120,'GEN',true,now()),
('LOAN','Loans payable',2,1,130,'GEN',true,now()),
('CREDIT_CARD','Credit cards',2,1,140,'GEN',true,now()),
('OTHER_LIAB','Other liabilities',2,1,150,'GEN',true,now()),

-- =========================
-- Equity
-- =========================
('CAPITAL','Owner capital',3,1,210,'GEN',true,now()),
('RET_EARN','Retained earnings',3,1,220,'GEN',true,now()),
('CURR_RESULT','Current year result',3,1,230,'GEN',true,now()),

-- =========================
-- Income
-- =========================
('SALES','Sales revenue',4,1,310,'GEN',true,now()),
('SERVICE_REV','Service revenue',4,1,320,'GEN',true,now()),
('WORK_REV','Work revenue',4,1,330,'GEN',true,now()),
('RENTAL_REV','Rental revenue',4,1,340,'GEN',true,now()),
('OTHER_INC','Other income',4,1,350,'GEN',true,now()),

-- =========================
-- Cost of Sales
-- =========================
('COGS','Cost of goods sold',5,0,410,'GEN',true,now()),
('COST_SERVICE','Cost of services',5,0,420,'GEN',true,now()),

-- =========================
-- Expenses
-- =========================
('RENT','Rent expense',6,0,510,'GEN',true,now()),
('PAYROLL','Payroll expense',6,0,520,'GEN',true,now()),
('UTILITIES','Utilities',6,0,530,'GEN',true,now()),
('INTERNET','Internet',6,0,540,'GEN',true,now()),
('MARKETING','Marketing',6,0,550,'GEN',true,now()),
('FUEL','Fuel',6,0,560,'GEN',true,now()),
('PROFESSIONAL','Professional services',6,0,570,'GEN',true,now()),
('OTHER_EXP','Other expenses',6,0,580,'GEN',true,now()),

-- =========================
-- Financial Result (RIF / SAT 700s)
-- Generic buckets
-- =========================
('FIN_INCOME','Financial income (RIF)',4,1,610,'SAT',true,now()),
('FIN_EXPENSE','Financial expense (RIF)',6,0,620,'SAT',true,now()),

-- More specific financial types (optional but recommended)
('INTEREST_INCOME','Interest income',4,1,611,'SAT',true,now()),
('INTEREST_EXPENSE','Interest expense',6,0,621,'SAT',true,now()),

('FX_GAIN','Foreign exchange gain',4,1,612,'SAT',true,now()),
('FX_LOSS','Foreign exchange loss',6,0,622,'SAT',true,now()),

('INFLATION_GAIN','Inflation gain / monetary position gain',4,1,613,'SAT',true,now()),
('INFLATION_LOSS','Inflation loss / monetary position loss',6,0,623,'SAT',true,now()),

('BANK_FEES_INCOME','Bank fees income (uncommon)',4,1,614,'SAT',true,now()),
('BANK_FEES_EXPENSE','Bank fees expense',6,0,624,'SAT',true,now()),

('OTHER_FIN_INCOME','Other financial income',4,1,615,'SAT',true,now()),
('OTHER_FIN_EXPENSE','Other financial expense',6,0,625,'SAT',true,now()),

-- =========================
-- Memorandum (SAT 800s)
-- =========================
('MEM_DEBIT','Memorandum debit',7,0,710,'SAT',true,now()),
('MEM_CREDIT','Memorandum credit',7,1,720,'SAT',true,now());

COMMIT;
