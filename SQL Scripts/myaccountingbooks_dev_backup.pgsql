--
-- PostgreSQL database dump
--

\restrict hVMEVzJa2fNtj2Bd4qNl6GaIbG19ToD1XjIwUPw8Pdw1s4cFKwmhDPd3gsdG2uy

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-02-23 11:41:22 CST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 250 (class 1259 OID 16595)
-- Name: account; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.account (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_id uuid NOT NULL,
    account_role smallint DEFAULT 0 NOT NULL,
    code text,
    commodity_scu integer DEFAULT 100 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    is_placeholder boolean DEFAULT false NOT NULL,
    kind smallint DEFAULT 1 NOT NULL,
    name text DEFAULT 'No Name'::text NOT NULL,
    non_std_scu integer DEFAULT 0 NOT NULL,
    notes text,
    account_type_id uuid,
    commodity_id uuid,
    parent_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT chk_account_kind CHECK ((kind = ANY (ARRAY[0, 1, 2, 3, 4, 5, 6, 7, 8]))),
    CONSTRAINT chk_account_role CHECK ((account_role = ANY (ARRAY[0, 100, 101, 110, 120, 130, 131, 199, 200, 210, 220, 299, 300, 310, 320, 400, 410, 420, 430, 499, 500, 510, 600, 610, 620, 699, 700, 800, 4300, 4301, 4310, 4311, 4320, 4321, 4330, 4331, 4340, 4341, 4390, 4391, 900])))
);


ALTER TABLE public.account OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 16478)
-- Name: account_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.account_type (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text DEFAULT 'No Code'::text NOT NULL,
    name text DEFAULT 'No Name'::text NOT NULL,
    standard text DEFAULT 'SAT/NIIF'::text,
    kind smallint DEFAULT 1 NOT NULL,
    normal_balance smallint DEFAULT 0 NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.account_type OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 16452)
-- Name: auth_identity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_identity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_owner_id uuid NOT NULL,
    provider text NOT NULL,
    provider_user_id text NOT NULL,
    provider_email text,
    email_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.auth_identity OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 16891)
-- Name: coa_template; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coa_template (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    country text,
    locale text,
    industry text,
    version text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.coa_template OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 16911)
-- Name: coa_template_node; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coa_template_node (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_id uuid NOT NULL,
    code text NOT NULL,
    parent_code text,
    name text NOT NULL,
    level integer NOT NULL,
    kind smallint NOT NULL,
    role smallint NOT NULL,
    is_placeholder boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    account_type_code text,
    CONSTRAINT coa_template_node_level_check CHECK ((level >= 0))
);


ALTER TABLE public.coa_template_node OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 16506)
-- Name: commodity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.commodity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    mnemonic text DEFAULT 'MXN'::text NOT NULL,
    namespace text DEFAULT 'CURRENCY'::text NOT NULL,
    full_name text DEFAULT 'No Name'::text,
    fraction bigint DEFAULT 100 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.commodity OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 16951)
-- Name: enum_label; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.enum_label (
    enum_name text NOT NULL,
    enum_value integer NOT NULL,
    locale text NOT NULL,
    label text NOT NULL,
    description text
);


ALTER TABLE public.enum_label OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 16530)
-- Name: ledger; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_id uuid CONSTRAINT ledger_owner_id_not_null1 NOT NULL,
    name text DEFAULT 'No Name'::text NOT NULL,
    currency_code text DEFAULT 'MXN'::text NOT NULL,
    "precision" smallint DEFAULT 2 NOT NULL,
    template text DEFAULT 'SAT'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    currency_commodity_id uuid,
    root_account_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone,
    coa_template_id uuid
);


ALTER TABLE public.ledger OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 16428)
-- Name: ledger_owner; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ledger_owner (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    email_verified boolean DEFAULT false NOT NULL,
    password_hash text,
    display_name text DEFAULT 'No Name'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.ledger_owner OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 16567)
-- Name: payee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payee (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_id uuid NOT NULL,
    name text DEFAULT 'No Name'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.payee OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 16655)
-- Name: price; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.price (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    commodity_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    date timestamp with time zone DEFAULT now() NOT NULL,
    source text,
    type text,
    value_denom integer DEFAULT 100 NOT NULL,
    value_num bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.price OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 16829)
-- Name: recurrence; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recurrence (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    mult integer DEFAULT 1 NOT NULL,
    period_start timestamp with time zone,
    period_type text,
    weekend_adjust text DEFAULT 'none'::text NOT NULL,
    scheduled_transaction_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.recurrence OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 16855)
-- Name: scheduled_split; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scheduled_split (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    memo text,
    side smallint DEFAULT 0 NOT NULL,
    value_denom integer DEFAULT 0 NOT NULL,
    value_num bigint DEFAULT 0 NOT NULL,
    scheduled_transaction_id uuid NOT NULL,
    account_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.scheduled_split OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 16774)
-- Name: scheduled_transaction; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scheduled_transaction (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_id uuid NOT NULL,
    adv_creation integer DEFAULT 0 NOT NULL,
    adv_notify integer DEFAULT 1 NOT NULL,
    auto_create boolean DEFAULT false NOT NULL,
    auto_notify boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    end_date timestamp with time zone,
    instance_count integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_occur timestamp with time zone,
    name text,
    num_occur integer DEFAULT 0 NOT NULL,
    rem_occur integer DEFAULT 0 NOT NULL,
    start_date timestamp with time zone,
    currency_commodity_id uuid,
    payee_id uuid,
    template_root_account_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.scheduled_transaction OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 16731)
-- Name: split; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.split (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action text,
    amount numeric(38,10) DEFAULT 0.0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    memo text,
    quantity_denom integer DEFAULT 100 NOT NULL,
    quantity_num bigint DEFAULT 0 NOT NULL,
    reconcile_date timestamp with time zone,
    reconcile_state boolean DEFAULT false NOT NULL,
    side smallint DEFAULT 0 NOT NULL,
    value_denom integer DEFAULT 100 NOT NULL,
    value_num bigint DEFAULT 0 NOT NULL,
    account_id uuid NOT NULL,
    transaction_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.split OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 16691)
-- Name: transaction; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transaction (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ledger_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    enter_date timestamp with time zone DEFAULT now() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    memo text,
    num text,
    post_date timestamp with time zone DEFAULT now() NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    currency_commodity_id uuid,
    payee_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.transaction OWNER TO postgres;

--
-- TOC entry 4144 (class 0 OID 16595)
-- Dependencies: 250
-- Data for Name: account; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.account (id, ledger_id, account_role, code, commodity_scu, created_at, is_active, is_hidden, is_placeholder, kind, name, non_std_scu, notes, account_type_id, commodity_id, parent_id, updated_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4140 (class 0 OID 16478)
-- Dependencies: 246
-- Data for Name: account_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.account_type (id, code, name, standard, kind, normal_balance, sort_order, is_active, created_at, updated_at, revision, deleted_at) FROM stdin;
21c386f8-c714-4367-b997-8e92ce97c71b	SYSTEM	SYSTEM	GEN	0	0	0	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
d4015724-20a4-4ac6-93ef-57c651858bec	CASH	Cash	GEN	1	0	10	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
7622d2d5-b2f3-4e0b-8e70-d6546ef0eb25	BANK	Bank accounts	GEN	1	0	20	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
22aef939-afca-49c0-8e73-a2cb5fb4650c	AR	Accounts receivable	GEN	1	0	30	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
c991f7b7-763e-42cb-b0cb-56902ecafa3f	INVENTORY	Inventory	GEN	1	0	40	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
76226695-b752-4694-a106-52bc8a1e2e91	FIXED_ASSET	Fixed assets	GEN	1	0	50	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
8b657063-ccb7-402d-bb50-d3731b980799	ACCUM_DEPR	Accumulated depreciation	GEN	1	1	60	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
6c8d72cf-31c0-4a58-b0a0-08dd9fc227a7	PREPAID	Prepaid expenses	GEN	1	0	70	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
ee0278fc-81f5-4be0-8dd5-b1aab167d9fa	OTHER_ASSET	Other assets	GEN	1	0	80	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
612e73c0-b457-48cc-aadf-7a4b9c700367	AP	Accounts payable	GEN	2	1	110	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
d9a9be04-ad71-43db-b3c3-e605e8392328	TAX_PAYABLE	Taxes payable	GEN	2	1	120	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
61981f90-ee94-409e-849b-cc8650b7bc6f	LOAN	Loans payable	GEN	2	1	130	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
b9035ecb-5ba3-4a49-b230-860d4fa95b9a	CREDIT_CARD	Credit cards	GEN	2	1	140	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
80b8e03a-da54-4140-90f6-c45d07e1ba09	OTHER_LIAB	Other liabilities	GEN	2	1	150	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
22d8fa49-556e-439c-9e35-0485fa35b504	CAPITAL	Owner capital	GEN	3	1	210	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
c91c6e36-65a5-4bdc-9c92-7f65d54c53d0	RET_EARN	Retained earnings	GEN	3	1	220	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
f476dd08-9870-4a67-9144-2ec0a426a3a8	CURR_RESULT	Current year result	GEN	3	1	230	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
5f047593-fe5d-4464-95bd-79736a4c175b	SALES	Sales revenue	GEN	4	1	310	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
7f2e14eb-a5ae-4e45-ac6f-05c1f504d5cf	SERVICE_REV	Service revenue	GEN	4	1	320	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
74eeafc0-421b-4184-96d0-bc80e8d502b5	WORK_REV	Work revenue	GEN	4	1	330	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
9e0bc5ba-d907-4712-b634-02ddaa5c3ce7	RENTAL_REV	Rental revenue	GEN	4	1	340	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
80631fc9-5f2f-4f2e-9ef9-4c41b47a7cae	OTHER_INC	Other income	GEN	4	1	350	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
6a42fbca-cafd-41f8-b924-9b4d434376b4	COGS	Cost of goods sold	GEN	5	0	410	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
4ab9126f-dfc5-44fa-ac40-db5603647bb0	COST_SERVICE	Cost of services	GEN	5	0	420	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
1b0319c2-0769-423d-a85b-0bd04dfa280c	RENT	Rent expense	GEN	6	0	510	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
34bc8c8d-e4a4-4015-9938-f4c031ddecda	PAYROLL	Payroll expense	GEN	6	0	520	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
2d4ce595-b661-404d-94f5-6a6e1827cd18	UTILITIES	Utilities	GEN	6	0	530	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
8ddaf011-8857-4ed6-8455-cf2de0e61d3f	INTERNET	Internet	GEN	6	0	540	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
565376b6-8e85-45df-bbd4-dc7a65fd77f4	MARKETING	Marketing	GEN	6	0	550	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
ba02d895-97df-40e9-8896-a50527a87a83	FUEL	Fuel	GEN	6	0	560	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
0d0ae5cb-9335-4a5c-b530-7928dfe5c856	PROFESSIONAL	Professional services	GEN	6	0	570	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
724a5658-ab1b-4802-bdaa-c512c6d115ef	OTHER_EXP	Other expenses	GEN	6	0	580	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
89d05d1d-8b8b-4feb-bbde-9b49debf2457	FIN_INCOME	Financial income (RIF)	SAT	4	1	610	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
d38f3862-58bf-457b-87ef-684311ac3258	FIN_EXPENSE	Financial expense (RIF)	SAT	6	0	620	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
a400bbde-b932-49fe-a26e-c87dff27da86	INTEREST_INCOME	Interest income	SAT	4	1	611	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
1a977298-5817-4af4-9f4b-1e0c51b11870	INTEREST_EXPENSE	Interest expense	SAT	6	0	621	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
082cf855-edee-48d2-a886-99ed5b5d2f8b	FX_GAIN	Foreign exchange gain	SAT	4	1	612	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
de74e2a9-0407-462b-b5ce-7265b09d5e3d	FX_LOSS	Foreign exchange loss	SAT	6	0	622	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
5cd0295b-041f-43e9-925c-96f7d7c80829	INFLATION_GAIN	Inflation gain / monetary position gain	SAT	4	1	613	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
b5b4e5fc-0864-4bab-8331-261ea5cbe398	INFLATION_LOSS	Inflation loss / monetary position loss	SAT	6	0	623	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
83c33f66-b507-418a-994a-c45790be70db	BANK_FEES_INCOME	Bank fees income (uncommon)	SAT	4	1	614	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
3204c448-dc4a-4533-bf85-1bb1e2eb0ac7	BANK_FEES_EXPENSE	Bank fees expense	SAT	6	0	624	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
968a3374-111c-4473-b9e6-7a05dded7ee5	OTHER_FIN_INCOME	Other financial income	SAT	4	1	615	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
c71611eb-dbcc-4f59-b8e9-2b5ec8e6b625	OTHER_FIN_EXPENSE	Other financial expense	SAT	6	0	625	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
f6253737-9d72-47d5-961a-0221549a448a	MEM_DEBIT	Memorandum debit	SAT	7	0	710	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
f94c9070-e453-4caf-8b25-b73e4c8aa8e1	MEM_CREDIT	Memorandum credit	SAT	7	1	720	t	2026-02-03 15:38:26.118484-06	2026-02-03 15:38:26.118484-06	0	\N
\.


--
-- TOC entry 4139 (class 0 OID 16452)
-- Dependencies: 245
-- Data for Name: auth_identity; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_identity (id, ledger_owner_id, provider, provider_user_id, provider_email, email_verified, created_at, last_login_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4151 (class 0 OID 16891)
-- Dependencies: 257
-- Data for Name: coa_template; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coa_template (id, code, name, description, country, locale, industry, version, is_active, created_at, updated_at) FROM stdin;
fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	PERSONALES_2026	Personal Chart of Accounts 2026	Personal chart of accounts (Mexico-oriented) for 2026	MX	es-MX	\N	v1	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06
2dcdfa08-ce3a-4c75-8d76-6566257437d3	SAT_2025	SAT 2025 Business Chart of Accounts (Agrupador-based)	SAT (Mexico) agrupador-based business chart of accounts, 2025 edition	MX	es-MX	\N	v1	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06
\.


--
-- TOC entry 4152 (class 0 OID 16911)
-- Dependencies: 258
-- Data for Name: coa_template_node; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coa_template_node (id, template_id, code, parent_code, name, level, kind, role, is_placeholder, created_at, updated_at, account_type_code) FROM stdin;
64e0be15-2ef2-4171-85c2-cdd6873e3bbd	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	000-00.000.00-000.000	\N	Raíz	0	0	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
58ca028e-ecb9-4fe2-b46e-51494bbb6a4e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-00.000.00-000.000	000-00.000.00-000.000	Activos	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
b7561cc3-5277-41aa-8d3b-e5587573db62	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.000.00-000.000	100-00.000.00-000.000	Activo Circulante	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
56717094-bb20-4eae-8cff-0af266b862e9	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.001.00-000.000	100-01.000.00-000.000	Caja	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2d603be2-0039-4e9c-8c9e-4134eb1ce3aa	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.002.00-000.000	100-01.000.00-000.000	Certificados de depósito	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
639a093a-0818-481f-8bf4-8d6c7de51be2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.003.00-000.000	100-01.000.00-000.000	Cuentas de ahorro	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
32f23baa-9a30-45ad-8e60-f3b76f398c35	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.004.00-000.000	100-01.000.00-000.000	Cuentas de cheques	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
cb031ceb-75af-43ad-a179-152aa14847ed	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.005.00-000.000	100-01.000.00-000.000	Préstamos realizados	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
21f8b830-754c-4b00-8e5e-11d74d2b5f10	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.005.01-000.000	100-01.005.00-000.000	Familia	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
10ec74e1-13de-4ee4-a7a2-818daab05cf8	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.005.02-000.000	100-01.005.00-000.000	Otros	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9ddc212e-32aa-4e00-9d52-09d265062258	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-01.006.06-000.000	100-01.000.00-000.000	Inversiones temporales	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
fdadd036-0b72-4304-826c-f555eb83a681	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.000.00-000.000	100-00.000.00-000.000	Activo No Circulante	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
05d34315-5626-4d8c-9b3c-2af80546dba7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.001.00-000.000	100-02.000.00-000.000	Propiedades, Planta y Equipo	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9628bf2d-8d2b-4b4d-9b76-e8cbb1c4d644	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.001.01-000.000	100-02.001.00-000.000	Terrenos	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
bae240ac-85c8-4eb5-9a2f-cb4e2530f7b0	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.001.02-000.000	100-02.001.00-000.000	Edificios	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d62bc74b-1a5f-41cd-bc36-ba81216421a2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.001.03-000.000	100-02.001.00-000.000	Maquinaria y Equipo	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8f3ff385-6911-4077-a75a-68a3aa07f600	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.001.04-000.000	100-02.001.00-000.000	Mobiliario y Equipo de Oficina	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
74c0b9b2-6b24-4ca4-a09a-dde9f844f616	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.001.05-000.000	100-02.001.00-000.000	Vehículos	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
361017e8-9908-497c-b816-c7a9b7f35862	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.002.00-000.000	100-02.000.00-000.000	Depreciación Acumulada	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9fb5ce03-1ff4-4ed1-b3a5-84d2a79f2842	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.002.01-000.000	100-02.002.00-000.000	Dep. Edificios	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0ff4d8e7-6e10-4449-8080-186bb38864d7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.002.02-000.000	100-02.002.00-000.000	Dep. Maquinaria	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
28cf15e4-d45f-4187-be92-0fb77df1fb80	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.002.03-000.000	100-02.002.00-000.000	Dep. Vehículos	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
70360bd6-60b0-4b15-adfb-1fc4af5265d2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.00-000.000	100-02.000.00-000.000	Inversiones a Largo Plazo	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
5d83c9bb-c8ca-4f92-a7e6-c70f1fe00faf	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.01-000.000	100-02.003.00-000.000	Ahorro para el retiro	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
4a663bba-f1ca-430d-af3c-4294c887ef11	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.01-001.000	100-02.003.01-000.000	Acciones	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
07749629-f683-49a0-8318-14c4c06e0add	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.01-002.000	100-02.003.01-000.000	Ahorros	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8b9520dd-a1d8-468d-8818-e0faaa448eac	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.01-003.000	100-02.003.01-000.000	Bonos	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c1645094-cf95-46d3-9c6a-897d828b71f0	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.01-004.000	100-02.003.01-000.000	Fondos de Inversión	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d54b11c2-7aa1-4c86-be07-5085683e282c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.01-005.000	100-02.003.01-000.000	Índice de Mercado	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
bac456cf-2336-485e-aa6f-eb9626be12c6	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.02-000.000	100-02.003.00-000.000	Cuentas de Corretaje	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a817bad7-4831-4b6f-b13a-e3787d378c54	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.02-001.000	100-02.003.02-000.000	Acciones	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0aed08b5-b6c3-4856-8a54-b509a1a0c34a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.02-002.000	100-02.003.02-000.000	Bonos	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
fd8fd38e-288f-457e-aebb-2b0c8c675cc6	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.02-003.000	100-02.003.02-000.000	Fondos de Inversión	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a2c6c44c-7165-46d5-8102-bb2c9c4f2524	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.003.02-004.000	100-02.003.02-000.000	Índice de Mercado	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
63ea5673-e823-4b86-9465-f9f73b89a5ea	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.004.00-000.000	100-02.000.00-000.000	Activos Intangibles	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
cc235d6c-248d-4c6d-a968-ccf87750171a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.004.01-000.000	100-02.004.00-000.000	Marcas	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6cd5e140-1fd6-4b5f-9328-041be6ea7fe6	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.004.02-000.000	100-02.004.00-000.000	Patentes	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2ce8d7f2-ac50-417a-87bc-bf57241698a8	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.004.03-000.000	100-02.004.00-000.000	Software	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c54bca12-66ce-4ff4-95f0-9ff646522f2d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-02.004.04-000.000	100-02.004.00-000.000	Licencias	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
aa49217b-1afa-4c13-a951-fb603663567c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-03.000.00-000.000	100-00.000.00-000.000	Otros Activos	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
bc9199a2-0dea-470f-a4b0-226497f262bd	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-03.001.00-000.000	100-03.000.00-000.000	Depósitos en Garantía	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c4017a39-9d83-4e9a-a8d0-9661014abc96	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-03.002.00-000.000	100-03.000.00-000.000	Préstamos realizados a largo plazo	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
59d07edf-e570-4cc3-b1df-49ab21c43372	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-03.002.01-000.000	100-03.002.00-000.000	Familia	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c86a7c2b-5b47-45fa-a03d-ba4d11309eb9	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	100-03.002.02-000.000	100-03.002.00-000.000	Otros	0	1	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
27ace6e3-6734-47db-bcb0-278b35d32521	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-00.000.00-000.000	000-00.000.00-000.000	Pasivos	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d0ae9b5e-ad57-4c35-afd6-79623729227f	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-01.000.00-000.000	200-00.000.00-000.000	Pasivo Circulante	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
5bba2543-91ad-494e-ad44-be4b9d9a21c0	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-01.001.00-000.000	200-01.000.00-000.000	Préstamos no bancarios	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e52d1aee-0d4a-4b7d-9999-9916d934c86a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-01.002.00-000.000	200-01.000.00-000.000	Créditos Bancarios a Corto Plazo	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
66b1956b-7a59-4663-9f21-86b75613ecad	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-01.003.00-000.000	200-01.000.00-000.000	Tarjetas de Crédito	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
b4eafb6e-35d8-4eb6-899d-493165a61605	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-02.000.00-000.000	200-00.000.00-000.000	Pasivo No Circulante	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
60b7f8e3-320c-488d-85fb-16b6b5c3aefe	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-02.001.00-000.000	200-02.000.00-000.000	Préstamos Bancarios a Largo Plazo	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
859a97d8-b8f3-4bc9-8ba2-4b6605bd9c71	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-02.002.00-000.000	200-02.000.00-000.000	Arrendamientos Financieros	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
02d13c31-672d-4afa-8ab1-1c10053e5c19	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-02.003.00-000.000	200-02.000.00-000.000	Hipotecas	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
5567a2cb-3737-4a66-8868-9c08bb1b82b5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	200-02.004.00-000.000	200-02.000.00-000.000	Obligaciones Fiscales a Largo Plazo	0	2	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
cad3dbd5-4f5b-4791-9c2f-eb74d855ae2e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	300-00.000.00-000.000	000-00.000.00-000.000	Capital	0	3	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
3863cfa7-4825-44f2-b4c6-daa96bc07e1b	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	300-01.000.00-000.000	300-00.000.00-000.000	Balance inicial	0	3	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d682d7f0-0677-4803-abbf-b56bd720277b	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-00.000.00-000.000	000-00.000.00-000.000	Ingresos	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
18c5c402-f957-4cab-8c6f-d6228fdb8bdd	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-01.000.00-000.000	400-00.000.00-000.000	Ingresos por Sueldos y Salarios	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ef2148cc-2654-41dd-9a0d-660b673d97ee	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-02.000.00-000.000	400-00.000.00-000.000	Ingresos por Bonos Laborales	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
56ef01ba-a255-41c1-950b-bab75722f9fc	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-02.001.00-000.000	400-02.000.00-000.000	Aguinaldo	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
65c89de7-b07d-4761-a2a5-216e9fe3e361	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-02.002.00-000.000	400-02.000.00-000.000	Prima Vacacional	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a8b444fe-bd7a-4fb5-b8ba-a1bc87f30f97	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-03.000.00-000.000	400-00.000.00-000.000	Ingresos por Pensiones	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d51820a9-0b12-44af-841f-0e75460bc392	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.000.00-000.000	400-00.000.00-000.000	Ingresos Financieros	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
96125395-98d9-467b-b4bc-5424e8637dd9	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.001.00-000.000	400-04.000.00-000.000	Intereses	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0a22e235-a601-4677-b4eb-301c471db2df	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.001.01-000.000	400-04.001.00-000.000	Intereses por Ahorros	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
b120c0c7-56cb-403a-ab34-446415a4ae1a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.001.02-000.000	400-04.001.00-000.000	Intereses por Bonos	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a08a3cbd-9d50-4174-a112-0cb062d36623	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.001.03-000.000	400-04.001.00-000.000	Intereses por Certificados	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ef33b698-d2f5-4158-a2a3-670c86e55e6e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.001.04-000.000	400-04.001.00-000.000	Intereses por Cheques	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2f368be2-33b6-4ec0-b9e2-c122bd2d9064	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.001.05-000.000	400-04.001.00-000.000	Intereses por Mercado de Monedas	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
3b30c8d0-11a1-483e-ac27-5482dedf3284	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.001.06-000.000	400-04.001.00-000.000	Otros Intereses	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
18894baa-eb37-4089-ad6c-517a02626b6c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-04.001.07-000.000	400-04.000.00-000.000	Rendimiento de inversiones	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a7ade452-6bb9-478d-aac2-b2743fc5614c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-05.000.00-000.000	400-00.000.00-000.000	Ingresos por Honorarios	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e85a9afd-10c3-43ec-b727-e92f1434f9be	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-06.000.00-000.000	400-00.000.00-000.000	Ingresos por Rentas	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
86070c3e-06da-4312-8987-8b8d022b7de5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.000.00-000.000	400-00.000.00-000.000	Otros Ingresos	0	4	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c22b6aef-3ff5-4e20-96d4-4dcf6614241e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.001.00-000.000	400-07.000.00-000.000	Anticipos Laborales	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f9f768a1-806a-4321-b6a9-6bdc3d752bac	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.002.00-000.000	400-07.000.00-000.000	Aportaciones Patronales	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
7edf81b5-cabb-424f-8f50-4ca95fde70ee	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.003.00-000.000	400-07.000.00-000.000	Apoyo Gubernamental	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
be21d668-85e0-4d17-a370-a9044db75ed5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.004.00-000.000	400-07.000.00-000.000	Apoyos Alimenticios	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
224f0360-b8bb-4259-ab77-661aaf673113	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.005.00-000.000	400-07.000.00-000.000	Ingresos por devolución de impuestos	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
7b948f6c-39a8-4cec-b5ca-3b493e2f1207	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.006.00-000.000	400-07.000.00-000.000	Ingresos por devolución de compras	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
4fa3d428-5c59-489c-b40e-4feed236234c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.007.00-000.000	400-07.000.00-000.000	Premios por Sorteos y Loterías	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8ac2f7de-1db0-44d7-91a2-3a2c213549d1	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.008.00-000.000	400-07.000.00-000.000	Préstamos	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
db052676-cc0e-44b8-a19d-700bd7245a29	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	400-07.009.00-000.000	400-07.000.00-000.000	Puntos redimidos	0	4	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c274f117-117c-4387-81fa-ac64b065f0c6	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-00.000.00-000.000	000-00.000.00-000.000	Egresos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d5ffb504-dde1-4de4-be94-d3c740225343	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-01.000.00-000.000	500-00.000.00-000.000	Ajustes	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8e7f60df-e3ff-468d-9620-29c5c2f04161	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-02.000.00-000.000	500-00.000.00-000.000	Alcohol y Tabaco	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
01ba1510-2f13-47e9-bb16-1c87f2145c01	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-02.001.00-000.000	500-02.000.00-000.000	Destilados	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9655a102-6aab-4be7-9629-2b85e4e64dc4	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-02.002.00-000.000	500-02.000.00-000.000	Fermentados	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ee9e9a7e-2545-4381-90b0-56c57d0285fa	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-02.003.00-000.000	500-02.000.00-000.000	Otras bebidas	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
33bd2705-9fe3-4bc7-85d8-223bc4c5a0b0	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-02.004.00-000.000	500-02.000.00-000.000	Tabaco	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
506ec46f-cdab-4c34-8e3b-44353aab00c5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.000.00-000.000	500-00.000.00-000.000	Alimentos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ac8a57f3-51d8-474b-af93-22da3649955b	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.001.00-000.000	500-03.000.00-000.000	Comida para llevar	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
24f2c03f-58f8-4582-b7f7-6a6dad84a54d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.002.00-000.000	500-03.000.00-000.000	Restaurantes y cocinas	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
fe2d4db0-2f5d-41c3-beef-bd48c1342342	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.003.00-000.000	500-03.000.00-000.000	Comestibles	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d8762584-66cd-4fa6-b9b7-d2fdcc86f211	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.003.01-000.000	500-03.003.00-000.000	Bebidas no alcohólicas	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
03db6adf-5e34-4290-9ff6-a926e692aff7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.003.02-000.000	500-03.003.00-000.000	Carnes	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
7404ddb8-d7bd-4e1b-8a48-727a69fdf248	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.003.03-000.000	500-03.003.00-000.000	Congelados	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d97082db-8a0d-4419-b6e8-5b4730b746c2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.003.04-000.000	500-03.003.00-000.000	Despensa	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
fe6cbecb-154f-4adc-ac50-5913c90adf51	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.003.05-000.000	500-03.003.00-000.000	Huevos y Lácteos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c61cf1db-52bd-4f77-9715-9cdee7c33dae	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.003.06-000.000	500-03.003.00-000.000	Panadería y Tortillería	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2dbbdb10-1bd7-4ba5-99dd-71b4b6a98535	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-03.003.07-000.000	500-03.003.00-000.000	Snacks	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
4dd4a074-4cbb-4521-af99-237a80229f62	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.000.00-000.000	500-00.000.00-000.000	Automóvil	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6132d035-2831-44af-aae6-3b07dcf2946f	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.001.00-000.000	500-04.000.00-000.000	Accesorios	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8f5689be-8d4b-4653-93c3-6c3574797a45	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.002.00-000.000	500-04.000.00-000.000	Combustible y Aditivos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e1a737b2-43cd-497d-a9dc-3924a4a1190f	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.002.01-000.000	500-04.002.00-000.000	Combustible	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
798290b5-b229-4d37-918d-5cbae2190da5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.002.02-000.000	500-04.002.00-000.000	Aditivos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
514e0a05-da4d-41f8-ae95-d5d6d4ef7019	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.003.00-000.000	500-04.000.00-000.000	Cuotas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
355e4ef8-bfd7-4d0f-bd7b-3aa9f1045416	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.004.00-000.000	500-04.000.00-000.000	Estacionamientos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8c3b975e-f2dc-4348-88d9-62a09d0cd18d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.005.00-000.000	500-04.000.00-000.000	Reparaciones y Mantenimiento	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
723193e8-f093-4eb2-9bfe-980991311a12	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.005.01-000.000	500-04.005.00-000.000	Refacciones	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9c0b15e9-ebf2-42ee-864d-e034153206e7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.005.02-000.000	500-04.005.00-000.000	Mantenimiento	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ce5e07f8-4d66-4531-8878-00ee7ae11e6e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.005.03-000.000	500-04.005.00-000.000	Reparaciones	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e2b250e8-faa5-4a3d-9482-c1f79953ab1d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.006.00-000.000	500-04.000.00-000.000	Pago de automóvil	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d9cae9b0-1bd2-41bc-91ca-6fe3d53534cc	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-04.007.00-000.000	500-04.000.00-000.000	Servicios de Limpieza	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2d1d070e-90f2-48e2-888b-06db50fb9240	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-05.000.00-000.000	500-00.000.00-000.000	Cuidado Personal	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
bac6ec84-889d-42ad-a1b2-dc95fb63df10	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-05.001.00-000.000	500-05.000.00-000.000	Cortes de cabello	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2d6f92c0-df56-4254-8258-ce1be906020e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-05.002.00-000.000	500-05.000.00-000.000	Lociones y perfumes	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
caeafd99-1f27-46ae-a6c6-d6501b6e6bd3	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-05.003.00-000.000	500-05.000.00-000.000	Manicure y pedicure	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f692637c-9fc8-4b03-9433-e86745a95926	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-05.004.00-000.000	500-05.000.00-000.000	Productos de higiene personal	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6908802b-633d-4bbf-b675-a88e9954a409	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-05.005.00-000.000	500-05.000.00-000.000	Tratamientos de belleza	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6a3f1363-d528-429f-8f90-4559216bf9d3	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.000.00-000.000	500-00.000.00-000.000	Cuidado de la Salud	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
abb1df71-de3c-4590-b48a-0e3dca12cef4	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.00-000.000	500-06.000.00-000.000	Salud	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f2c117fb-7ac5-4603-8c35-825038c1273d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.01-000.000	500-06.001.00-000.000	Accesorios	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
62a07b42-6e99-45bf-83df-6c9bfd14ced2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.02-000.000	500-06.001.00-000.000	Dispositivos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
65e97b67-3fb4-4d97-a07d-5686e74bc1f0	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.03-000.000	500-06.001.00-000.000	Gastos de Enfermería	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
5816d965-85ae-4b2f-ac86-142b972cedb6	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.04-000.000	500-06.001.00-000.000	Gastos de Hospital	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f3ade4b5-7fdc-4b65-8b16-2a531364f95e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.05-000.000	500-06.001.00-000.000	Laboratorios	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e99fec24-8482-4a46-9b71-af648d62d6c4	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.06-000.000	500-06.001.00-000.000	Medicinas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6a196d32-2989-4245-9e9d-19bea42be148	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.07-000.000	500-06.001.00-000.000	Honorarios médicos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
1b9dc42d-ae75-4ff2-9352-c0d38b00de5a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.08-000.000	500-06.001.00-000.000	Salud dental	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
999fa7bc-c14f-47c2-98d8-c5f9c76626ad	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.09-000.000	500-06.001.00-000.000	Salud ocular	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
1127ce81-c8d6-4685-8280-a1db438b4f11	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.10-000.000	500-06.001.00-000.000	Salud sexual	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d78ca33d-a5ad-45f7-9c94-4f524782cf6e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.11-000.000	500-06.001.00-000.000	Salud mental	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
fc9dc681-8354-43dc-8855-00216f6fd0c4	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.12-000.000	500-06.001.00-000.000	Suministros	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
394d6aa5-44a8-47d1-922a-6aa038143241	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.001.13-000.000	500-06.001.00-000.000	Vitaminas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e0a85889-6196-4d5e-b7bc-6ae481fd2d26	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.002.00-000.000	500-06.000.00-000.000	Ejercicio y deportes	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f368ab58-9d83-4a8b-a177-1d9d9731e8df	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.002.01-000.000	500-06.002.00-000.000	Accesorios deportivos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9378f05a-392f-44f9-98e4-1fa198ab34c7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.002.02-000.000	500-06.002.00-000.000	Equipo de ejercicio	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8d7fa55f-8819-47bf-b5f2-751240f7d39e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.002.03-000.000	500-06.002.00-000.000	Inscripción a eventos deportivos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d93262a8-9308-4331-8ba0-d158750661d4	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-06.002.04-000.000	500-06.002.00-000.000	Gimansios	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
242d9c6a-59ac-47aa-a16a-0776a9ce7e7c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-07.000.00-000.000	500-00.000.00-000.000	Donativos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
91213a38-cb5f-417c-ae16-427ac86cd576	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-07.001.00-000.000	500-07.000.00-000.000	Donativo sin recibo	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
90a79ea0-c0ce-41c3-8fd9-de8dacd471a7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-07.002.00-000.000	500-07.000.00-000.000	Donativo con recibo	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
898b40fe-a04c-4a3d-a2a2-1d4a87ac47b3	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-07.003.00-000.000	500-07.000.00-000.000	Propinas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c71d003d-78a6-43d3-8ce1-6e09bbdcf0cc	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-08.000.00-000.000	500-00.000.00-000.000	Educación	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
867ebee2-42f5-4740-a777-b624f389e193	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-08.001.00-000.000	500-08.000.00-000.000	Colegiatura	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ddddb0c2-c420-4804-b04f-8645ddd92a81	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-08.002.00-000.000	500-08.000.00-000.000	Cuotas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
3ab0f5df-08c5-4ba1-a797-50ca1bff0d13	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-08.003.00-000.000	500-08.000.00-000.000	Libros	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
eb0f6377-c627-4c9a-8736-4b213e385ba4	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-08.004.00-000.000	500-08.000.00-000.000	MOOCs	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
288a9737-01a4-4b04-922a-7645715a6126	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-08.005.00-000.000	500-08.000.00-000.000	Recursos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
1fd12129-762d-4907-b628-2e9cbcb1b4a5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.000.00-000.000	500-00.000.00-000.000	Entretenimiento	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6244821f-a278-4bac-b785-d99d5c889674	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.001.00-000.000	500-09.000.00-000.000	Actividades Recreativas	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
342573f5-950e-424c-9ae5-2b1b443daa55	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.001.01-000.000	500-09.001.00-000.000	Conciertos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
56bc0fa5-1777-43e5-a0e9-8722ac684931	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.001.02-000.000	500-09.001.00-000.000	Eventos Culturales	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c064da7b-401f-4b01-a374-3dd76178a9bb	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.001.03-000.000	500-09.001.00-000.000	Eventos Deportivos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
da2ade3c-fdbd-43e2-9f5d-9bd2b23a2843	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.002.00-000.000	500-09.000.00-000.000	Hobbies	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
498be95d-a634-4926-8e3f-6b55a9c4622d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.003.00-000.000	500-09.000.00-000.000	Libros y Revistas	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
5fe03e53-7de3-4f1e-a2a7-85d2449cfa92	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.003.01-000.000	500-09.003.00-000.000	Digitales	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f4427b12-f8ee-47fc-98b2-3cb05f6d9680	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.003.02-000.000	500-09.003.00-000.000	Físicos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
93522ba0-1ede-45fa-b79e-63769a1bf19c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.004.00-000.000	500-09.000.00-000.000	Películas	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
177a778f-14ca-4247-a64a-f2488fa289cf	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.004.01-000.000	500-09.004.00-000.000	Cine	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a82e93d8-474e-4832-8734-2c5f022c2863	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-09.004.02-000.000	500-09.004.00-000.000	Digitales	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
3a7c97ae-42fe-4fd6-b8f5-c35d16d91941	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.000.00-000.000	500-00.000.00-000.000	Electrónicos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
176f32b1-f392-40c5-a79d-30ad4c05b38e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.001.00-000.000	500-10.000.00-000.000	Equipo de cómputo	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ec0a31c4-71a3-4ef0-8e4a-a4f96b97634a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.001.01-000.000	500-10.001.00-000.000	Computadoras de escritorio	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2fa2b763-4f28-4218-a1b8-69667fc2875f	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.001.02-000.000	500-10.001.00-000.000	Computadoras portátiles	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
7abdeeae-4478-4c76-9ef8-02d144f66c9d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.001.03-000.000	500-10.001.00-000.000	Servidores	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
4b283fed-cb73-43b8-b732-5c5d486ec22d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.002.00-000.000	500-10.000.00-000.000	Equipo de impresión y digitalización	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f8541667-eda1-4e22-8b29-d4c5777865e1	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.002.01-000.000	500-10.002.00-000.000	Impresoras	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f7dd2f09-f193-47aa-a617-157fff25a1da	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.002.02-000.000	500-10.002.00-000.000	Plotters	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f928f5b3-994e-474a-94cd-e7d52ef0f395	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.002.03-000.000	500-10.002.00-000.000	Scanners	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f2915443-3093-4acb-a1c9-94c0218e86e1	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.002.04-000.000	500-10.002.00-000.000	Multifuncionales	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f74079d9-d13d-492a-a8bb-b6e0329421aa	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.003.00-000.000	500-10.000.00-000.000	Equipo de video	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0e3ada8b-be3b-425a-b455-6f92aeed774a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.003.01-000.000	500-10.003.00-000.000	Televisores	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
fac02fde-2f22-4548-9aa3-bb9cff76a3ab	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.003.02-000.000	500-10.003.00-000.000	Pantallas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0f391932-47c8-40a4-8ae1-aa7cf5d7e3b0	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.003.03-000.000	500-10.003.00-000.000	Videocámaras	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
4e24b1ef-8f23-4479-9a28-e27d14751159	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.004.00-000.000	500-10.000.00-000.000	Equipo de audio	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
7f5c2471-b211-408f-8e6e-8f8714b69f4d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.004.01-000.000	500-10.004.00-000.000	Bocinas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
53fb129e-34ca-497a-acf5-b7b977d8964c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.004.02-000.000	500-10.004.00-000.000	Micrófonos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d4253ac0-3306-4403-8128-9335e980dc03	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.004.03-000.000	500-10.004.00-000.000	Multicomponentes	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
496f87cc-c828-4d0f-b0fe-dba8170f72c7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.005.00-000.000	500-10.000.00-000.000	Equipo de IoT	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8de66539-01bb-4cd8-b3bf-9d6a55d57f77	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.005.01-000.000	500-10.005.00-000.000	Hubs de hogar inteligente	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2782d115-c5ad-418c-96d7-d59e1f85eed2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.005.02-000.000	500-10.005.00-000.000	Procesadores	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
72a298fa-6ccf-4613-bfd3-306302eb1b18	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.005.03-000.000	500-10.005.00-000.000	Sensores	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d8d3764a-e7e5-4620-b1a7-de6e7218f08e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.005.04-000.000	500-10.005.00-000.000	Actuadores	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
bcaac00a-5c02-4d75-b376-09af28f1a000	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.006.00-000.000	500-10.000.00-000.000	Equipo de comunicaciones	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
33183593-6ffb-4790-8ac7-d5894f7d117f	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.006.01-000.000	500-10.006.00-000.000	Teléfonos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9acfd7b5-da25-49cb-8963-d77ea77af665	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.006.02-000.000	500-10.006.00-000.000	Teléfonos celulares	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0664f2f7-1329-4674-83b2-c59ff15fbb73	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.006.03-000.000	500-10.006.00-000.000	Radio-comunicadores	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
087a29a7-ad59-42fb-b37b-615cf36c116e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.007.00-000.000	500-10.000.00-000.000	Equipo de conectividad	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f9686cc2-38a7-4a67-8faf-39eb17929cbf	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.008.00-000.000	500-10.000.00-000.000	Accesorios	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d93063d6-666a-463a-9092-6db82ccfba2f	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.009.00-000.000	500-10.000.00-000.000	Reparaciones	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c175a30b-d6c4-422c-a4e8-f89fca5af841	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.010.00-000.000	500-10.000.00-000.000	Suministros	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
1d3bdfd1-15b8-4d02-a683-cb5cd1042983	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.011.00-000.000	500-10.000.00-000.000	Tabletas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
bfa05e60-1af8-414f-99a9-cba88641839b	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-10.012.00-000.000	500-10.000.00-000.000	Wearables	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c2dbc16c-d31a-4bdf-93de-f3a6ff8d8b95	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.000.00-000.000	500-00.000.00-000.000	Vivienda y Gastos del Hogar	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
69ccdba6-d56a-4fd6-8124-b18da5a66b5d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.001.00-000.000	500-11.000.00-000.000	Renta	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
48587f1a-50af-4c10-b93d-0a46ffebbbc2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.002.00-000.000	500-11.000.00-000.000	Consumibles	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
781aa458-a7cb-4ef8-8bdf-09ad992b8dbd	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.003.00-000.000	500-11.000.00-000.000	Iluminación	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
11e96fb7-a472-481b-8e77-c62f41095e88	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.004.00-000.000	500-11.000.00-000.000	Electrodomésticos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
99ef9de8-67a9-4dc8-a388-ef3bbf2f9c28	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.005.00-000.000	500-11.000.00-000.000	Artículos de limpieza	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0e6a227a-f0d0-431a-9931-218e353935df	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.006.00-000.000	500-11.000.00-000.000	Herramientas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0746eda1-acee-4843-b7cd-2f6d3bcf158b	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.007.00-000.000	500-11.000.00-000.000	Lavandería/Tintorería	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
009d73cf-eb5f-4921-8cd2-73700b658fab	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.008.00-000.000	500-11.000.00-000.000	Mantenimiento	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c0859ae1-6886-4ca8-ba5d-bd7c8d1a6f65	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.009.00-000.000	500-11.000.00-000.000	Mejoras a la Casa	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a22036b4-d1a4-49b7-b236-4c046e8779f9	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.010.00-000.000	500-11.000.00-000.000	Mobiliario	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e8409b83-18af-4eb5-b6c9-6d15cfa78d23	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.011.00-000.000	500-11.000.00-000.000	Reparaciones del hogar	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
73bae4e2-a9fa-47d9-a7e7-1aae7f01c399	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.012.00-000.000	500-11.000.00-000.000	Línea blanca	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
4a4d9ce5-2489-4489-b4f3-5f3b38f1c3e8	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.013.00-000.000	500-11.000.00-000.000	Seguridad y vigilancia	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
05d1449d-5404-48d9-bc98-e800629ea913	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.014.00-000.000	500-11.000.00-000.000	Servicios de jardinería	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
bf9ae5d0-78b7-4af7-ab12-8071c143ce1d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.015.00-000.000	500-11.000.00-000.000	Servicios de limpieza	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
95523c98-0824-4031-8699-22e3f860021b	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-11.016.00-000.000	500-11.000.00-000.000	Suministros de cocina	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
58428a5c-b14f-4c55-aac3-a0da8cfc055c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-12.000.00-000.000	500-00.000.00-000.000	Gastos Financieros	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
459f47e4-a2fe-4c6c-a8b5-4497d9c80c54	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-12.001.00-000.000	500-12.000.00-000.000	Pérdidas en Inversiones	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a2d7b2ae-7e38-41dc-b8fa-06a8464494e1	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-12.002.00-000.000	500-12.000.00-000.000	Comisiones Bancarias	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2ff6bc6d-2c90-4291-bdcc-41a4dada47d9	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-12.003.00-000.000	500-12.000.00-000.000	Intereses Pagados	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e9b84e2a-ee91-449f-a9a5-44504ea71b90	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-13.000.00-000.000	500-00.000.00-000.000	Gastos Laborales	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
7b250de4-2a88-430c-8663-83371714155f	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-13.001.00-000.000	500-13.000.00-000.000	Gasto reembolsable	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
fabd4db3-dbc1-4171-87a8-22211d1e0171	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-13.002.00-000.000	500-13.000.00-000.000	Gasto no reembolsable	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
19e9a7d5-96cc-4f01-914d-1a32133ffede	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-13.003.00-000.000	500-13.000.00-000.000	Devolución de anticipo	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a55cb02b-0831-41b3-92f6-e1c417533c93	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.000.00-000.000	500-00.000.00-000.000	Impuestos y Contribuciones	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
30b117f8-905a-4768-8d20-98fa7b245559	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.001.00-000.000	500-14.000.00-000.000	Impuestos Federales	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
b282228e-5c05-4f52-962f-b03028116b58	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.001.01-000.000	500-14.001.00-000.000	Impuesto sobre la renta (ISR)	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8555284e-d0f3-4061-b67c-3f0bace7b04a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.001.02-000.000	500-14.001.00-000.000	Impuesto al valor agregado (IVA)	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8cf558f4-3abe-41c7-b1ca-2411000536fd	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.002.00-000.000	500-14.000.00-000.000	Impuestos Estatales	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
036d4daa-271a-4f56-aab6-f506731fec89	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.002.01-000.000	500-14.002.00-000.000	Derechos Vehiculares	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
18a4d00b-b596-416c-841f-cc21e20a805e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.002.02-000.000	500-14.002.00-000.000	Emplacamiento	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
bc7a8fef-e9e2-43cc-8788-6d9d325ba56b	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.003.00-000.000	500-14.000.00-000.000	Impuestos Locales	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
cb3a97dd-59f7-491f-9ef7-366cf0226362	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.003.01-000.000	500-14.003.00-000.000	Predial	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2fe25f97-c7f9-4baa-bd0a-fc63992ddf6d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.004.00-000.000	500-14.000.00-000.000	Medicare	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e05b7d08-c6de-42ea-adac-2da3de00aad7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.005.00-000.000	500-14.000.00-000.000	Otros Impuestos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f616d528-97d7-4f35-a9f6-afe618e77c97	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-14.006.00-000.000	500-14.000.00-000.000	Seguridad Social	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
b9925d62-55c0-444b-bc1f-dd8a74c89f34	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-15.000.00-000.000	500-00.000.00-000.000	Mascotas	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8eef3c08-f94c-4e1b-9ed4-b3ff96d2047d	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-15.001.00-000.000	500-15.000.00-000.000	Adquisición de mascotas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c02f7fa3-87d3-4ea9-9a6c-3cb236184ef5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-15.002.00-000.000	500-15.000.00-000.000	Cuidado de mascotas	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
459a0b32-5f19-4d4c-beeb-30448d13bce7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-15.002.01-000.000	500-15.002.00-000.000	Alimento para mascotas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f06f5c31-23b3-453e-bc56-bd1e334ff244	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-15.002.02-000.000	500-15.002.00-000.000	Medicinas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f9947e36-ae89-4772-a1cf-a5ab8ea78c34	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-15.002.03-000.000	500-15.002.00-000.000	Suministros	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
5bf99add-95f8-49fd-9b01-746b60c10b2e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-15.002.04-000.000	500-15.002.00-000.000	Veterinario	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6808b269-5652-4316-8e35-fee387375355	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-15.002.05-000.000	500-15.002.00-000.000	Baño y aseo de mascotas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
b0ade178-72b6-43f9-b2ec-6bb113dce8f7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-16.000.00-000.000	500-00.000.00-000.000	Misceláneos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c96a95f2-3b81-41d7-ad0e-fabf2dc8e42e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-16.001.00-000.000	500-16.000.00-000.000	Apuestas, Sorteos y Juegos de Azar	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
f4ef5ac7-6d78-4c7a-94d9-60b317b88f9a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-16.002.00-000.000	500-16.000.00-000.000	Artículos diversos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
72d6094c-69e8-43cf-bed1-7e3cb08e39fb	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-16.003.00-000.000	500-16.000.00-000.000	Decoraciones	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6a0b6b10-1510-46f4-b04d-912791e592ce	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-16.004.00-000.000	500-16.000.00-000.000	Regalos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
38fd7c1e-9172-4b80-8cb8-d2aa1553632c	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-16.005.00-000.000	500-16.000.00-000.000	Suministros de oficina	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e2d049a5-7f99-4fb1-bfcb-9ba4455d09a5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-17.000.00-000.000	500-00.000.00-000.000	Préstamos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
25855b02-e60c-4559-a6b2-e6e1e8f5b454	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-17.001.00-000.000	500-17.000.00-000.000	Interés del préstamo	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
25fd388b-2964-4902-b17e-037532bb96ed	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-17.002.00-000.000	500-17.000.00-000.000	Interés del préstamo automotriz	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6756c861-9256-445c-a761-c8838cc3881b	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-17.003.00-000.000	500-17.000.00-000.000	Interés del préstamo educativo	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
1a0221e2-d96e-4fd0-8a33-39186dd7d780	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-17.004.00-000.000	500-17.000.00-000.000	Interés hipotecario	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8ec6b4cd-33d6-4f48-aa56-a9c2dbb80e7a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-18.000.00-000.000	500-00.000.00-000.000	Retiro de Efectivo	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
4b84c5bd-0747-4a01-9c6b-0ffbe6e0572a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-19.000.00-000.000	500-00.000.00-000.000	Ropa y Calzado	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9159fdf7-b323-4704-b272-f246ac6a6238	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-19.001.00-000.000	500-19.000.00-000.000	Accesorios	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
dc054fec-53a2-47dc-95a6-372977c8a77e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-19.002.00-000.000	500-19.000.00-000.000	Calzado	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6b660074-947a-4bc1-8d20-69804019666a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-19.003.00-000.000	500-19.000.00-000.000	Ropa	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
5117f7cc-f061-44c1-adfc-7f50d191aa36	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.000.00-000.000	500-00.000.00-000.000	Servicios	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e234681b-36e8-4017-bf4d-cdfecfb55c4e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.001.00-000.000	500-20.000.00-000.000	Servicios Básicos	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
8ecc05e5-acf3-49c2-bfc4-d3668c68a045	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.001.01-000.000	500-20.001.00-000.000	Agua y alcantarllado	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
903a6e3a-0e3a-4afc-87df-c434023b7d52	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.001.02-000.000	500-20.001.00-000.000	Electricidad	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
cbba4e85-1b46-4be8-a65e-d817d9ebe6f4	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.001.03-000.000	500-20.001.00-000.000	Gas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
30ee0ea6-bc53-4497-9d36-8dc564e07643	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.001.04-000.000	500-20.001.00-000.000	Manejo de desechos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
2f9240ae-ed2f-4090-bf97-0d3b58718c0e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.002.00-000.000	500-20.000.00-000.000	Otros Servicios	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
0c6c7b1f-5d94-43fc-bda8-0e470d8b43d7	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.002.01-000.000	500-20.002.00-000.000	Servicios en línea	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
c94ba2ac-558d-4bbb-b4cc-0d8d2ee7a8af	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.002.02-000.000	500-20.002.00-000.000	Servicios funerarios	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d09ad4e6-8c9a-4720-bdc0-561bfc81a697	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.03	600.00.602.00	Tiempos extras	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2cfa02cf-09a7-4700-964b-d16a582bc037	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.002.03-000.000	500-20.002.00-000.000	Telefonía e Internet	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
eaa6ea26-c11f-4157-bedd-e8f15f078fb9	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.002.04-000.000	500-20.002.00-000.000	Telefonía celular	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
af9dede4-13fa-4811-9c4a-68766d139d0f	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.002.04-001.000	500-20.002.04-000.000	Plan celular	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6fe97153-a6a6-4679-98d1-5b22161421e1	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.002.04-002.000	500-20.002.04-000.000	Recarga	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ca4d12aa-9113-4b28-bbac-348d9d89a626	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-20.002.05-000.000	500-20.002.00-000.000	TV por Cable/Satélite	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
05a2d220-74ef-445b-87bd-29e6089d4193	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-21.000.00-000.000	500-00.000.00-000.000	Seguros	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
dc50dc2b-7b40-477c-ac2f-5ec341257b64	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-21.001.00-000.000	500-21.000.00-000.000	Seguro de aparatos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
6d54f3e6-5a28-4cb0-9d1d-0f981cb20a2e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-21.002.00-000.000	500-21.000.00-000.000	Seguro de automóvil	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
eb08378b-5721-4ec4-a2b1-2d128939027e	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-21.003.00-000.000	500-21.000.00-000.000	Seguro del hogar	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
42603019-ed9f-444d-91f3-7765177e2f41	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-21.004.00-000.000	500-21.000.00-000.000	Seguro de salud	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
977aba90-21eb-428a-8c81-1ec3eec40334	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-21.005.00-000.000	500-21.000.00-000.000	Seguro de tarjetas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
cc2b9b2f-3860-4966-ad6f-e387033a5ba2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-21.006.00-000.000	500-21.000.00-000.000	Seguro de vida	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
e461b9e9-8616-4c85-bdee-49a116ab8f47	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-21.007.00-000.000	500-21.000.00-000.000	Seguro de asistencia	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
843a66e2-2f96-4809-b58f-ecfdd16b9ad2	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-22.000.00-000.000	500-00.000.00-000.000	Servicios de Transporte	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
ebd03bb6-05ee-447a-aafd-adf7189a16a5	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-22.001.00-000.000	500-22.000.00-000.000	Taxis	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
72406135-bdfc-4040-8884-e163bee972f9	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-22.002.00-000.000	500-22.000.00-000.000	Transporte público	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
567f1a5b-8e73-4d5b-831c-64da15dd2a2a	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-23.000.00-000.000	500-00.000.00-000.000	Suscripciones y Membresías	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
d88bfad3-cb77-465f-9370-3ec57cae0064	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-23.001.00-000.000	500-23.000.00-000.000	Club de Salud	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
25a09dd7-8538-402b-8340-82bd77ae2cf1	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-23.002.00-000.000	500-23.000.00-000.000	Membresías	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
cabfc494-7079-42b0-a611-256f0bfbacdd	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-23.003.00-000.000	500-23.000.00-000.000	Períodicos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
69a45dda-60fa-4aa9-a0d4-b10ad5e87fa0	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-23.004.00-000.000	500-23.000.00-000.000	Servicios de Streaming	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
309b1119-c064-465b-8ecc-f7c20aa98185	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-23.005.00-000.000	500-23.000.00-000.000	Software	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
9d068b3c-430a-4c02-9012-a0ac665e3f55	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-24.000.00-000.000	500-00.000.00-000.000	Viajes y Vacaciones	0	6	0	t	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
96f4237e-a789-471e-b5a9-d25746583b58	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-24.001.00-000.000	500-24.000.00-000.000	Boletos	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
eb8820af-6a2b-4fcc-b637-b7981014d6f6	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-24.002.00-000.000	500-24.000.00-000.000	Hospedaje	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
a1c6ea33-7562-4a13-9cfa-dd05d9cacd79	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-24.003.00-000.000	500-24.000.00-000.000	Maletas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
26f43221-157e-48ae-8db3-2a43963cfd80	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-24.004.00-000.000	500-24.000.00-000.000	Pasaporte	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
5cebbeaa-f63a-411d-979e-4d1f9312a6cf	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-24.005.00-000.000	500-24.000.00-000.000	Peaje	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
7c2e1c31-0889-4b3b-bc51-f128eef30f42	fb50b9cc-3da5-4bb1-a356-e65a3a4164ba	500-24.006.00-000.000	500-24.000.00-000.000	Tarifas	0	6	0	f	2026-02-05 15:51:48.689729-06	2026-02-05 15:51:48.689729-06	\N
690b5ca8-800d-4091-a0c1-cf630d07b7f4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	000.00.000.00	\N	Raíz	0	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
adc0b33e-9f44-4285-863e-127bef1483d9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.00.000.00	000.00.000.00	Activo	1	1	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1762f3a8-bcc9-4e6e-a02e-baab7e816435	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.00.000.00	000.00.000.00	Pasivo	1	2	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7737b98c-1fc0-4b0e-bebe-36a3f1c9908e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.000.00	000.00.000.00	Capital contable	1	3	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f8f261f7-8586-4cc7-8d1b-2097c1d514c6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.000.00	000.00.000.00	Ingresos	1	4	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6041e432-0f27-47ae-b8c6-c49eed02c4b8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.000.00	000.00.000.00	Costos	1	5	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
abf1c74c-3941-4e5f-805f-6e73edacbf49	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.000.00	000.00.000.00	Gastos	1	6	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
46176139-7770-40ee-b8c1-60be4f002c5f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.000.00	000.00.000.00	Resultado integral de financiamiento	1	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ea5e576f-d60f-49da-b7cd-0c829259037e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.000.00	000.00.000.00	Cuentas de orden	1	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
271ac54e-4a9d-4b0b-a233-51ee0d29956e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.000.00	100.00.000.00	Activo a corto plazo	2	1	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
90b6f0a0-9d3e-40a1-b814-39e8ff8df69b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.000.00	100.00.000.00	Activo a largo plazo	2	1	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
10fca67c-92a3-4d97-91ab-7a9553fef872	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.000.00	200.00.000.00	Pasivo a corto plazo	2	2	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a815440a-befd-46ac-a35f-a7c3581aab78	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.000.00	200.00.000.00	Pasivo a largo plazo	2	2	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
46762c0d-a650-49d9-987a-b010323a5eb7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.301.00	300.00.000.00	Capital social	2	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cfd39f77-8328-4165-9c77-06baad489bcf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.302.00	300.00.000.00	Patrimonio	2	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4de49c30-a1f3-4de8-bba3-000d380baaf4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.303.00	300.00.000.00	Reserva legal	2	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
34e60a01-ca1c-476c-aef5-f6aaab670969	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.304.00	300.00.000.00	Resultado de ejercicios anteriores	2	3	320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3dcb10ea-6afc-4020-9f62-d5bccfec88f0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.305.00	300.00.000.00	Resultado del ejercicio	2	3	320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dcdef496-5cd7-4c33-b2b9-a8dc1986d3df	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.306.00	300.00.000.00	Otras cuentas de capital	2	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0b5373f0-8c49-4c56-91a9-f39cb5516788	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.00	400.00.000.00	Ingresos	2	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
800a2071-943e-4a20-8f3b-b553190181d0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.402.00	400.00.000.00	Devoluciones, descuentos o bonificaciones sobre ingresos	2	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e5cc027f-9a78-486e-9d5b-0a53e7593885	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.403.00	400.00.000.00	Otros ingresos	2	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7ae5ac64-70b7-4941-b2a7-6c0d9613a735	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.00	500.00.000.00	Costo de venta y/o servicio	2	5	510	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5ce7021d-c513-4016-9d33-ad08cb6c6c2a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.502.00	500.00.000.00	Compras	2	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e1d9ea25-727f-4d3a-ae4c-ba1c7e29b3b1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.503.00	500.00.000.00	Devoluciones, descuentos o bonificaciones sobre compras	2	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
96c3a461-fe37-4a86-b3e2-5f33448e57f7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.00	500.00.000.00	Otras cuentas de costos	2	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
03a83fd6-065d-46eb-be25-ab4a8a0caee2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.505.00	500.00.000.00	Costo de activo fijo	2	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
31d2fe43-314c-4120-8328-bef79933dd48	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.00	600.00.000.00	Gastos generales	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
64fcd29c-b2e1-4873-8214-75ae893741b7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.00	600.00.000.00	Gastos de venta	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7dc97f00-ca7a-4810-9676-27e961a993ad	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.00	600.00.000.00	Gastos de administración	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6e78c004-38a6-45c1-8513-a87460e347f5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.00	600.00.000.00	Gastos de fabricación	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
da519c88-6d9f-450b-be02-353a364ce636	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.00	600.00.000.00	Mano de obra directa	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f4ddcb6f-62e7-44d9-b65a-e270d4465fb4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.606.00	600.00.000.00	Facilidades administrativas fiscales	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5021ca0a-7a2c-4b49-a410-2ee35a190bb9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.607.00	600.00.000.00	Participación de los trabajadores en las utilidades	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
50cfd0b2-304c-4dd1-94d9-9ab606310df8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.608.00	600.00.000.00	Participación en resultados de subsidiarias	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e4d7f6e3-2424-4d69-a12d-538843b1020f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.609.00	600.00.000.00	Participación en resultados de asociadas	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c9df3fd6-c87c-4c62-9e9b-832b38d57dd8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.610.00	600.00.000.00	Participación de los trabajadores en las utilidades diferida	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cf5bbaf1-804a-4882-97fd-8740cbe591ca	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.611.00	600.00.000.00	Impuesto Sobre la renta	2	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
92ae52e6-db5e-421b-b5a9-424681478a70	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.612.00	600.00.000.00	Gastos no deducibles para CUFIN	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
afb1a7b7-7bc9-4658-b413-f7b5c545764d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.00	600.00.000.00	Depreciación contable	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
63435971-d96f-4878-9fe0-16a4e670fe73	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.00	600.00.000.00	Amortización contable	2	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ce33df01-30bf-4c32-bb68-d47e04be845a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.00	700.00.000.00	Gastos financieros	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9d49a52c-fbc1-4e04-a4f1-67a59c49cdad	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.00	700.00.000.00	Productos financieros	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4b4c8bd9-e3eb-44a5-b261-404bcd1f8624	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.00	700.00.000.00	Otros gastos	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
70a7f490-d207-49a4-a367-062f1a5053be	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.00	700.00.000.00	Otros productos	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
58084450-9804-4580-926f-1432644e234e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.801.00	800.00.000.00	UFIN del ejercicio	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e984c804-fb50-4de2-b455-3a3e78ab0094	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.802.00	800.00.000.00	CUFIN del ejercicio	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
83b455f4-66d9-4a57-b180-27f6f95f173a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.803.00	800.00.000.00	CUFIN de ejercicios anteriores	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bbe341bb-e243-4769-8bac-9250d88d97de	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.804.00	800.00.000.00	CUFINRE del ejercicio	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5c76385a-3fef-48a4-b7fe-19eb00074ac2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.805.00	800.00.000.00	CUFINRE de ejercicios anteriores	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
908d92d2-cd90-4a12-af56-d5be03b42b40	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.806.00	800.00.000.00	CUCA del ejercicio	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a1a9a113-b492-4712-8d74-b94c8759301a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.807.00	800.00.000.00	CUCA de ejercicios anteriores	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
06fbcd80-9ae9-403c-a168-43ecc6c09f7f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.808.00	800.00.000.00	Ajuste anual por inflación acumulable	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0798de1b-0a1b-4773-987b-22d819c94bd6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.809.00	800.00.000.00	Ajuste anual por inflación deducible	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0f62cc6a-8709-4e94-b1c7-2dc0567ab944	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.810.00	800.00.000.00	Deducción de inversión	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3905d0bd-3c82-4a28-b1e3-60afee88c489	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.811.00	800.00.000.00	Utilidad o pérdida fiscal en venta y/o baja de activo fijo	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3328f0f6-fc30-4bbd-9691-b08f88dfdf30	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.812.00	800.00.000.00	Utilidad o pérdida fiscal en venta acciones o partes sociales	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
378cb33d-fbb2-4600-98db-1b3df11f63b6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.813.00	800.00.000.00	Pérdidas fiscales pendientes de amortizar actualizadas de ejercicios anteriores	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ef749c8b-0071-4714-9522-0d357f140506	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.814.00	800.00.000.00	Mercancías recibidas en consignación	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7d258f4d-c3df-41f0-8df4-3bf391639a1b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.815.00	800.00.000.00	Crédito fiscal de IVA e IEPS por la importación de mercancías para empresas certificadas	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
840007fe-534d-4940-a020-54b0e3a81b2a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.816.00	800.00.000.00	Crédito fiscal de IVA e IEPS por la importación de activos fijos para empresas certificadas	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
af46567a-9b6d-4b8a-907e-9315942a55c1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.817.00	800.00.000.00	Otras cuentas de orden	2	0	0	t	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d2773c08-7d66-43c7-9587-25380b2a1b0e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.101.00	100.01.000.00	Caja	3	1	100	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
84b15956-31a6-494c-9a13-ba05dd86f3c7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.102.00	100.01.000.00	Bancos	3	1	101	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8dc89087-facf-4648-a580-0ea15dd65d68	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.103.00	100.01.000.00	Inversiones	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
17632742-ebd1-4b0d-9191-41269100d861	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.104.00	100.01.000.00	Otros instrumentos financieros	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1389c7ed-ad0b-4d60-86e8-40ac41916384	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.105.00	100.01.000.00	Clientes	3	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
30492ff2-a447-4ce8-88b3-f51e7b693faa	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.00	100.01.000.00	Cuentas y documentos por cobrar a corto plazo	3	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a23c6349-657d-42a7-8ea3-147ed38068e4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.107.00	100.01.000.00	Deudores diversos	3	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9ebe728d-f46e-4507-9649-36a038dcf0f2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.108.00	100.01.000.00	Estimación de cuentas incobrables	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2565ae7d-3162-4e5b-a449-15cbc4e35049	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.00	100.01.000.00	Pagos anticipados	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c1c88684-a82a-483e-8b5f-4ccaf752b5dc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.110.00	100.01.000.00	Subsidio al empleo por aplicar	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cff86ff6-7d0a-42f8-a145-b83278ab89e4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.111.00	100.01.000.00	Crédito al diesel por acreditar	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
17e34c05-ab6f-47b5-a26d-79acb6ac6ef0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.112.00	100.01.000.00	Otros estímulos	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a09cf6f4-9bc5-4f8f-b949-25384a08715d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.00	100.01.000.00	Impuestos a favor	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fba9e47a-9f29-46c0-9e38-2e1630d97133	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.114.00	100.01.000.00	Pagos provisionales	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3466bad1-bd70-4d77-9d6b-a0fae6765dc6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.115.00	100.01.000.00	Inventario	3	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f8d27c68-1131-400f-a284-230d506c0c55	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.116.00	100.01.000.00	Estimación de inventarios obsoletos y de lento movimiento	3	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7bd182e4-5b7b-46ef-8ea1-283395830d69	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.117.00	100.01.000.00	Obras en proceso de inmuebles	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a06c35d7-cb1f-4f5d-8a9f-28dd2ed4cd69	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.118.00	100.01.000.00	Impuestos acreditables pagados	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dfd4fae6-0694-4447-a3ba-c6c838c4d26c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.119.00	100.01.000.00	Impuestos acreditables por pagar	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d2dd1f86-0870-4d35-b8c8-c29109cc6215	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.120.00	100.01.000.00	Anticipo a proveedores	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
12717f67-c8dc-49cc-9362-f05a5042fd2e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.121.00	100.01.000.00	Otros activos a corto plazo	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6b2e8494-8494-4699-93c1-f7493e8d97dd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.151.00	100.02.000.00	Terrenos	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b80349f7-749e-446b-a243-3176960d13b1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.152.00	100.02.000.00	Edificios	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0814691f-e7ef-4e9a-9957-11a05a6d150d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.153.00	100.02.000.00	Maquinaria y equipo	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8620ae78-d8d5-4ccf-a3de-13555664e5ef	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.154.00	100.02.000.00	Automóviles, autobuses, camiones de carga, tractocamiones, montacargas y remolques	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5739dd6d-af71-4099-8ac0-abd1fe26b696	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.155.00	100.02.000.00	Mobiliario y equipo de oficina	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c702cb14-cc64-479f-b93a-9ce76da758af	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.156.00	100.02.000.00	Equipo de cómputo	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
afeed65c-2c9f-4e12-9228-a6461fdfa1c9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.157.00	100.02.000.00	Equipo de comunicación	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
90378bb0-e831-41c1-b4a9-694a3a19e4fd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.158.00	100.02.000.00	Activos biológicos, vegetales y semovientes	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
629220c3-afa0-4a6b-80a2-269ceda98da0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.159.00	100.02.000.00	Obras en proceso de activos fijos	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
38280fe0-1e6d-40c3-b9af-1c15a345b161	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.160.00	100.02.000.00	Otros activos fijos	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
767aeca8-a1d8-4cc3-a793-e43c51d55a39	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.161.00	100.02.000.00	Ferrocarriles	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
20f0838b-8c92-4c68-83f4-ab33523a065e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.162.00	100.02.000.00	Embarcaciones	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3ddf0847-3aa8-4bb4-be14-3de78705ae23	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.163.00	100.02.000.00	Aviones	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
780ac5b9-ce7e-479a-981a-1d589ca76515	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.164.00	100.02.000.00	Troqueles, moldes, matrices y herramental	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
86857d21-4104-4340-9a51-c8ce9d3d10bc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.165.00	100.02.000.00	Equipo de comunicaciones telefónicas	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1c7ef3bc-7ce3-48b6-b1ea-2902e1e85293	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.166.00	100.02.000.00	Equipo de comunicación satelital	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
15eadb0a-7bbd-4147-a4a1-968cc4b0bdd7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.167.00	100.02.000.00	Equipo de adaptaciones para personas con capacidades diferentes	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
816eb102-6ad1-40ab-92be-5a9b2aa09fba	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.168.00	100.02.000.00	Maquinaria y equipo de generación de energía de fuentes renovables o de sistemas de 1 cogeneración de electricidad eficiente	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
88060c4e-c8f7-49a1-8b33-f30b8b79687d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.169.00	100.02.000.00	Otra maquinaria y equipo	3	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
068be1c4-258c-4487-ba7c-2829422657d7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.170.00	100.02.000.00	Adaptaciones y mejoras	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
992c32ab-3b21-4448-8bff-7dcf62d9e4f5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.00	100.02.000.00	Depreciación acumulada de activos fijos	3	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
94269468-9b2b-4ba2-aac4-3c298a7c8db1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.00	100.02.000.00	Pérdida por deterioro acumulado de activos fijos	3	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8d88f119-a74d-48db-b23d-b3d3dad6875d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.173.00	100.02.000.00	Gastos diferidos	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f0576502-0b7a-47d3-b687-c24043b336d7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.174.00	100.02.000.00	Gastos pre operativos	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6176c915-85a0-4e20-8f2e-91818dab19e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.175.00	100.02.000.00	Regalías, asistencia técnica y otros gastos diferidos	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d4917b21-4996-4ef0-93ee-cb3949f2d73c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.176.00	100.02.000.00	Activos intangibles	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d4f4ff9a-f0e3-45a5-b9c6-5d57597b45aa	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.177.00	100.02.000.00	Gastos de organización	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4b345e3a-c072-49b4-be48-7c5a3e86fe78	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.178.00	100.02.000.00	Investigación y desarrollo de mercado	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
30fc63ba-7c73-4b6c-8c42-314438014de8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.179.00	100.02.000.00	Marcas y patentes	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f8a7e2a6-78e5-4a18-adf4-36291fe995da	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.180.00	100.02.000.00	Crédito mercantil	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2720d78b-c75b-4b86-9d0e-ce14eec5daa0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.181.00	100.02.000.00	Gastos de instalación	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
68acdd97-3fcb-46c4-be70-3659ff5f7d1a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.182.00	100.02.000.00	Otros activos diferidos	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1b531f60-4f90-41ee-b713-acd2673a83fd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.00	100.02.000.00	Amortización acumulada de activos diferidos	3	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8c7dd423-8a6c-42ec-98f7-18e399457d4b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.184.00	100.02.000.00	Depósitos en garantía	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
946a369e-41b6-4f3b-88eb-ae667db0104a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.185.00	100.02.000.00	Impuestos diferidos	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
717b9983-09ba-41ba-92d3-bfd5abc64fa5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.00	100.02.000.00	Cuentas y documentos por cobrar a largo plazo	3	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d4053200-0943-48f6-9686-99d4a9500557	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.187.00	100.02.000.00	Participación de los trabajadores en las utilidades diferidas	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a9c4ddbe-e82d-4c8f-8f40-fe040350dced	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.188.00	100.02.000.00	Inversiones permanentes en acciones	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
24a1d383-224b-4610-a2ba-781c51d9239c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.189.00	100.02.000.00	Estimación por deterioro de inversiones permanentes en acciones	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1483addb-4cf1-47b3-8fd0-2f481ab35a2c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.190.00	100.02.000.00	Otros instrumentos financieros	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dcee2c62-faf2-42a4-8f87-48408136d868	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.191.00	100.02.000.00	Otros activos a largo plazo	3	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
df94c8ea-8f77-4fd5-9078-2acf15c5898c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.201.00	200.01.000.00	Proveedores	3	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1122a69b-9cd3-49fc-92e2-db44ac2f6b40	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.00	200.01.000.00	Cuentas por pagar a corto plazo	3	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
82b8ed53-6e13-4b74-8554-6492fc66df6f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.00	200.01.000.00	Cobros anticipados a corto plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
24da28b4-ffbd-42a9-a5cd-d7dad41c0176	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.204.00	200.01.000.00	Instrumentos financieros a corto plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8e9a4f56-1789-458a-b8a6-7a331248157d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.205.00	200.01.000.00	Acreedores diversos a corto plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
66341382-51b1-4253-8f19-b7cf8f4f5928	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.206.00	200.01.000.00	Anticipo de cliente	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0b536564-5057-4605-a031-6e593a3bd5c2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.207.00	200.01.000.00	Impuestos trasladados	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a14d86bf-d6ac-40ed-a923-48e4b27b7bef	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.208.00	200.01.000.00	Impuestos trasladados cobrados	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7e80047e-7e97-48ef-9fdc-81ed7c88c353	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.209.00	200.01.000.00	Impuestos trasladados no cobrados	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b12a30eb-52b9-42f1-acad-0e230df65020	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.210.00	200.01.000.00	Provisión de sueldos y salarios por pagar	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1a90f7a4-c71b-40bd-b80a-1731a582d88e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.211.00	200.01.000.00	Provisión de contribuciones de seguridad social por pagar	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
eb265804-f714-4ea3-b0c4-3130157c6e8a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.212.00	200.01.000.00	Provisión de impuesto estatal sobre nómina por pagar	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4ec89a30-af85-44ce-86ae-a8a2fea7a305	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.213.00	200.01.000.00	Impuestos y derechos por pagar	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ac123afb-6d53-4d08-96ef-f04e3dd8bc31	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.214.00	200.01.000.00	Dividendos por pagar	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5571a07a-45cd-4a90-b072-fa411268ece1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.215.00	200.01.000.00	PTU por pagar	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fcc25870-d48c-48a0-a981-c26f4962af6b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.00	200.01.000.00	Impuestos retenidos	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5260bdaf-bf8d-40e7-8941-655f13f7eef8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.217.00	200.01.000.00	Pagos realizados por cuenta de terceros	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
63e32b84-292e-4b11-a8dc-19c7a331a2dc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.218.00	200.01.000.00	Otros pasivos a corto plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b46a8fcd-6ddc-48f5-acc7-6f083f885113	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.251.00	200.02.000.00	Acreedores diversos a largo plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
db03d4a5-edfa-4090-9175-3f42cb2c8ae9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.00	200.02.000.00	Cuentas por pagar a largo plazo	3	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a36150ea-3025-4cc2-a3f9-5bc22b005f89	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.00	200.02.000.00	Cobros anticipados a largo plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
42881f01-eb10-41a3-84cb-275160d8bc9c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.254.00	200.02.000.00	Instrumentos financieros a largo plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ad532037-d644-4f9c-b2ec-515d26159ce8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.255.00	200.02.000.00	Pasivos por beneficios a los empleados a largo plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bf770d47-8609-45b2-95bf-6d02ca3a42d7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.256.00	200.02.000.00	Otros pasivos a largo plazo	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
da7bbfdb-b120-445c-856c-7087f2916108	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.257.00	200.02.000.00	Participación de los trabajadores en las utilidades diferida	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
eb481481-b52c-4e2c-bad1-b578b9f99dde	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.258.00	200.02.000.00	Obligaciones contraídas de fideicomisos	3	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cc375a52-ee3e-4730-92ad-f4b7c5f12980	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.259.00	200.02.000.00	Impuestos diferidos	3	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ebf4cd64-b786-420b-ac6f-3e9b53517d13	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.260.00	200.02.000.00	Pasivos diferidos	3	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
83313ef9-2f20-4fe6-b041-9cecd9ada658	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.301.01	300.00.301.00	Capital fijo	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a55aea5c-09f4-4b49-9854-b30ad3819553	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.301.02	300.00.301.00	Capital variable	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
abe0ba87-5132-4781-ac0b-c15f3c1ab66d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.301.03	300.00.301.00	Aportaciones para futuros aumentos de capital	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
99aa59ca-c938-49f9-9512-b65ca7434969	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.301.04	300.00.301.00	Prima en suscripción de acciones	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
864dc2ff-9430-4bdc-b301-57aa5933bf87	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.301.05	300.00.301.00	Prima en suscripción de partes sociales	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2eef18b8-f855-457c-b729-c488471e8461	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.302.01	300.00.302.00	Patrimonio	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8cd20768-9ff4-4bd3-aa98-d36e36cf2209	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.302.02	300.00.302.00	Aportación patrimonial	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
478ff856-9e9d-4132-80d3-3b854f15f3fa	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.302.03	300.00.302.00	Déficit o remanente del ejercicio	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0bb91745-f24d-4590-bd07-8bf60b0f0d54	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.303.01	300.00.303.00	Reserva legal	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f3fcffd4-a394-4bd7-8afb-7c63abeac3e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.304.01	300.00.304.00	Utilidad de ejercicios anteriores	3	3	320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4402a2a9-709e-4bb5-bb23-75c9eccef77f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.304.02	300.00.304.00	Pérdida de ejercicios anteriores	3	3	320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fd449e21-358c-4b24-b3ef-565580bfd2fb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.304.03	300.00.304.00	Resultado integral de ejercicios anteriores	3	3	320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
50f3fe1f-fbe8-4bcc-8db5-3ca83c4876f5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.304.04	300.00.304.00	Déficit o remanente de ejercicio anteriores	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
70245c70-2d4a-482a-8f46-501ee4322ddf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.305.01	300.00.305.00	Utilidad del ejercicio	3	3	320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f77e7113-afdc-4955-87ac-955107964704	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.305.02	300.00.305.00	Pérdida del ejercicio	3	3	320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cdd69c9f-516e-4154-a35c-f9fee7196bc5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.305.03	300.00.305.00	Resultado integral	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1c9f8e64-25a2-4784-aaa1-c1b14dafe503	2dcdfa08-ce3a-4c75-8d76-6566257437d3	300.00.306.01	300.00.306.00	Otras cuentas de capital	3	3	300	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a80a362c-c4e8-4083-beaa-e00413db992f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.01	400.00.401.00	Ventas y/o servicios gravados a la tasa general	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c315ae58-9b4a-4b75-b5f6-e4481d1a9dfd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.02	400.00.401.00	Ventas y/o servicios gravados a la tasa general de contado	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
09564d5c-c3e6-4ab5-9638-6b8b0aa47d48	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.03	400.00.401.00	Ventas y/o servicios gravados a la tasa general a crédito	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8ab91ee2-7986-41a2-a698-98eaaf37f2bb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.04	400.00.401.00	Ventas y/o servicios gravados al 0%	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
398dd2a7-875a-4fe1-9a08-3277ac40d8c0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.05	400.00.401.00	Ventas y/o servicios gravados al 0% de contado	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2869591a-62a8-4f0b-a8b0-a250d8d3ecd4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.06	400.00.401.00	Ventas y/o servicios gravados al 0% a crédito	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
109481f4-1605-44ac-a09e-dc647f623951	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.07	400.00.401.00	Ventas y/o servicios exentos	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
643a0d8a-5fa3-4e17-a496-77db0021d650	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.08	400.00.401.00	Ventas y/o servicios exentos de contado	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
02ae7c21-6005-4b95-9b1e-36c7cc42aefe	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.09	400.00.401.00	Ventas y/o servicios exentos a crédito	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
19ea5197-5d30-4073-87be-50b9bab264ec	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.10	400.00.401.00	Ventas y/o servicios gravados a la tasa general nacionales partes relacionadas	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0fd0ca08-69d9-48a1-9737-4759aa6ee8d1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.11	400.00.401.00	Ventas y/o servicios gravados a la tasa general extranjeros partes relacionadas	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2474f977-16ce-4615-b287-70d769223fb5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.12	400.00.401.00	Ventas y/o servicios gravados al 0% nacionales partes relacionadas	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3e5b1d5a-8226-4026-9e80-adf82533a3b4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.13	400.00.401.00	Ventas y/o servicios gravados al 0% extranjeros partes relacionadas	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
312e83e7-39e7-44f5-8c41-907ecc4869ab	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.14	400.00.401.00	Ventas y/o servicios exentos nacionales partes relacionadas	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d3014a4f-8d52-4e9f-9426-292ddf37be0d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.15	400.00.401.00	Ventas y/o servicios exentos extranjeros partes relacionadas	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5ac7ce71-495b-4784-a9e6-178df21b39fd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.16	400.00.401.00	Ingresos por servicios administrativos	3	4	410	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
484b6aa4-888a-45fa-a881-02bc49d46e51	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.17	400.00.401.00	Ingresos por servicios administrativos nacionales partes relacionadas	3	4	410	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a0680f41-f656-4692-8f6f-7a2b66858b96	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.18	400.00.401.00	Ingresos por servicios administrativos extranjeros partes relacionadas	3	4	410	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
265ff94e-54fa-4826-8c4a-afa6283f70b0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.19	400.00.401.00	Ingresos por servicios profesionales	3	4	410	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7e44db08-adf1-48ab-9b80-1e077cf5dad1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.20	400.00.401.00	Ingresos por servicios profesionales nacionales partes relacionadas	3	4	410	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3c3220b4-18e4-42da-8782-84d9c2bd4261	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.21	400.00.401.00	Ingresos por servicios profesionales extranjeros partes relacionadas	3	4	410	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e419ee0d-3d20-43c7-bad5-be7650a70652	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.22	400.00.401.00	Ingresos por arrendamiento	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d10015fe-559d-4df7-81c6-c3949d47c6ad	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.23	400.00.401.00	Ingresos por arrendamiento nacionales partes relacionadas	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e01d2cc0-4862-45d4-a37c-e18c64fdb499	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.24	400.00.401.00	Ingresos por arrendamiento extranjeros partes relacionadas	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dd49ebd3-a840-4a60-aad1-1183184d291d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.25	400.00.401.00	Ingresos por exportación	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9509f2a0-5550-4634-a1d5-71acca906ac9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.26	400.00.401.00	Ingresos por comisiones	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3f7f263a-3fec-45c6-b473-c01a92b1923a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.27	400.00.401.00	Ingresos por maquila	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2c011692-4e97-4575-a170-e46411908362	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.28	400.00.401.00	Ingresos por coordinados	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
95a358f7-f687-4a67-b3fd-f441f8efdee1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.29	400.00.401.00	Ingresos por regalías	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fa4366c1-2d91-467d-97c3-6dbd98dd6ac3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.30	400.00.401.00	Ingresos por asistencia técnica	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
693df614-a385-4d01-9523-73e2ff7f0a8b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.31	400.00.401.00	Ingresos por donativos	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c13f8f8e-4760-4889-8bf1-97a2f6808e86	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.32	400.00.401.00	Ingresos por intereses (actividad propia)	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
74bf9938-4648-4107-a936-72f07dee2ea4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.33	400.00.401.00	Ingresos de copropiedad	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
149c0f04-8af5-4cc7-a699-abf493f20e3a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.34	400.00.401.00	Ingresos por fideicomisos	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
abbabd9f-0fa5-4160-82ea-e77d10ea58a1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.35	400.00.401.00	Ingresos por factoraje financiero	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d9292696-fab3-42d8-a97a-e5982a9ed558	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.36	400.00.401.00	Ingresos por arrendamiento financiero	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f68ed4f2-cdab-4146-bc5a-99b599154756	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.37	400.00.401.00	Ingresos de extranjeros con establecimiento en el país	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f94e7efe-b961-49b9-9fa3-957e1e5ac536	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.401.38	400.00.401.00	Otros ingresos propios	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2f2e69fb-242d-4b58-8756-850a6d5b644b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.402.01	400.00.402.00	Devoluciones, descuentos o bonificaciones sobre ventas y/o servicios a la tasa general	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bfa53955-51b9-4ad5-9b44-724117f01d1e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.402.02	400.00.402.00	Devoluciones, descuentos o bonificaciones sobre ventas y/o servicios al 0%	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2966233f-cc1f-4ebf-8481-9a056f119110	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.402.03	400.00.402.00	Devoluciones, descuentos o bonificaciones sobre ventas y/o servicios exentos	3	4	400	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a03c0278-7757-4df9-9407-0ac0e2bf2d2b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.402.04	400.00.402.00	Devoluciones, descuentos o bonificaciones de otros ingresos	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
74f695f8-cfb6-4c28-b433-1c484794017b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.403.01	400.00.403.00	Otros Ingresos	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
763fe03b-041a-49aa-8bbf-d298967d534d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.403.02	400.00.403.00	Otros ingresos nacionales parte relacionada	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6f57aa4c-2db2-4744-879f-b2d07a55c316	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.403.03	400.00.403.00	Otros ingresos extranjeros parte relacionada	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f9fc2ce0-a09f-48fe-9c62-3cad4ccc9f7d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.403.04	400.00.403.00	Ingresos por operaciones discontinuas	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4c8ceefa-517e-4083-a7e9-d887b7cc25db	2dcdfa08-ce3a-4c75-8d76-6566257437d3	400.00.403.05	400.00.403.00	Ingresos por condonación de adeudo	3	4	499	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
524173db-8852-430f-b446-53b11f0b504c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.01	500.00.501.00	Costo de venta	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cece8a60-e655-44b1-bd3c-7a8a34c1959d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.02	500.00.501.00	Costo de servicios (Mano de obra)	3	5	510	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
db5d7af6-e224-4970-9000-9d658b964245	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.03	500.00.501.00	Materia prima directa utilizada para la producción	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b1cd7083-45c2-4784-97a3-f40a4ee941d5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.04	500.00.501.00	Materia prima consumida en el proceso productivo	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cb4aa21e-a795-4199-bdb2-d5e6fdc0d400	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.05	500.00.501.00	Mano de obra directa consumida	3	5	510	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e3a3d7f2-34f1-486d-b390-ce3bbf1124b6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.06	500.00.501.00	Mano de obra directa	3	5	510	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2fcf5b31-4e63-48c6-af00-770a65f684ae	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.07	500.00.501.00	Cargos indirectos de producción	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
83d65f2c-8240-46ab-bba3-26faeba48901	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.501.08	500.00.501.00	Otros conceptos de costo	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
86e748c2-7d88-4697-8c3f-60e1be050dbf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.502.01	500.00.502.00	Compras nacionales	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fbee4c6d-5cdb-4a73-8315-85b0eaa46796	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.502.02	500.00.502.00	Compras nacionales parte relacionada	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ad2ff4b0-08d9-4dcf-ac6e-48a44bef7aa9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.502.03	500.00.502.00	Compras de Importación	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f5791ea4-d82d-430e-b89f-142aa1e0e7fe	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.502.04	500.00.502.00	Compras de Importación partes relacionadas	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fcd9c8cc-d11a-41e3-9b4f-48686b239a4d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.503.01	500.00.503.00	Devoluciones, descuentos o bonificaciones sobre compras	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cfe2027a-b92d-47f1-80dd-6bf61ccd5a0e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.01	500.00.504.00	Gastos indirectos de fabricación	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d914610d-effc-437e-936e-b56f9e049f82	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.02	500.00.504.00	Gastos indirectos de fabricación de partes relacionadas nacionales	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8b308833-5c3b-4ea2-913f-dddbefc33404	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.03	500.00.504.00	Gastos indirectos de fabricación de partes relacionadas extranjeras	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
66d4f01e-38ce-4173-9ef7-56bc6671040f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.04	500.00.504.00	Otras cuentas de costos incurridos	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cbd2abcd-7e3f-4dd9-8c3d-1c68f694c89b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.05	500.00.504.00	Otras cuentas de costos incurridos con partes relacionadas nacionales	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0e62c674-0ce4-406c-aabf-ee24525a7b01	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.06	500.00.504.00	Otras cuentas de costos incurridos con partes relacionadas extranjeras	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6e086153-2a79-4839-b093-be0634c843ac	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.07	500.00.504.00	Depreciación de edificios	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
829f3a90-e7a0-42f6-81d3-7120c3eaf9ae	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.08	500.00.504.00	Depreciación de maquinaria y equipo	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4fa2a088-4350-4a8d-a413-c7b48b5695f7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.09	500.00.504.00	Depreciación de automóviles, autobuses, camiones de carga, tractocamiones, montacargas y remolques	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6f92d759-fc68-4f68-8666-4cef1c002e04	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.10	500.00.504.00	Depreciación de mobiliario y equipo de oficina	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
332c711b-5124-4c11-b8b8-5e3f4cc5b75a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.11	500.00.504.00	Depreciación de equipo de cómputo	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
52855224-ef96-4d12-855d-db636f1137ec	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.12	500.00.504.00	Depreciación de equipo de comunicación	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4b56b7f3-3b4e-4cd5-9987-a8590198e99e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.13	500.00.504.00	Depreciación de activos biológicos, vegetales y semovientes	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
24f38a08-ad1f-4b79-94c5-9537245c8c52	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.14	500.00.504.00	Depreciación de otros activos fijos	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f68052d0-dc87-4917-aa6b-9a9bdac0f7d1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.15	500.00.504.00	Depreciación de ferrocarriles	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6efae2d0-d89c-4280-9b82-9c6e1bec8725	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.16	500.00.504.00	Depreciación de embarcaciones	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
adaf54ac-d286-40fe-9cb0-2989f487dee9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.17	500.00.504.00	Depreciación de aviones	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
22e76452-537b-4b0a-84b8-d8246449e680	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.18	500.00.504.00	Depreciación de troqueles, moldes, matrices y herramental	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c65fd785-e094-43a3-bf89-a77e2854d59d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.19	500.00.504.00	Depreciación de equipo de comunicaciones telefónicas	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f386a4a4-9111-432b-a2f2-bc8ddf9f48e2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.20	500.00.504.00	Depreciación de equipo de comunicación satelital	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
27a1ea0b-1302-411a-9f97-f78748ca53dc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.21	500.00.504.00	Depreciación de equipo de adaptaciones para personas con capacidades diferentes	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7d918fb7-b303-4de0-afec-bfd8b8002b71	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.22	500.00.504.00	Depreciación de maquinaria y equipo de generación de energía de fuentes renovables o de sistemas de cogeneración de electricidad eficiente	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6df9d3d2-555d-42d9-8451-364470909403	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.23	500.00.504.00	Depreciación de adaptaciones y mejoras	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2acb115a-48b4-4757-89f5-db5eeb6d7ddc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.24	500.00.504.00	Depreciación de otra maquinaria y equipo	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bb5453dd-89ed-47ad-8fd1-a511b5c2231c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.504.25	500.00.504.00	Otras cuentas de costos	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
03ebc5db-d427-4bd9-b5f6-16777c774052	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.505.01	500.00.505.00	Costo por venta de activo fijo	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
53911245-3b4f-48ef-bef2-c5ae2041c09c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	500.00.505.02	500.00.505.00	Costo por baja de activo fijo	3	5	500	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
481e88ed-bc8a-420f-a7ac-1b3d6ea3abfb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.01	600.00.601.00	Sueldos y salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
69657b12-9cd6-45ea-a2ed-7b81d1b70286	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.02	600.00.601.00	Compensaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
390c82eb-9e8f-4a4d-a2dc-1deed400bb9c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.03	600.00.601.00	Tiempos extras	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e9fde146-eecf-4f62-8900-b320ab1f447d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.04	600.00.601.00	Premios de asistencia	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d47d9ef2-41cc-48ca-8f28-65ddb611551a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.05	600.00.601.00	Premios de puntualidad	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
92b4bba9-e0ca-4a87-a73b-ec06fa8911d8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.06	600.00.601.00	Vacaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0bca0155-2557-45f6-8009-2ad23079ef45	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.07	600.00.601.00	Prima vacacional	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d035c45d-1c64-43ae-808a-bcabcf60e601	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.08	600.00.601.00	Prima dominical	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a9fc9b30-a339-44ae-8523-53c6454caf70	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.09	600.00.601.00	Días festivos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0ef70b9b-7830-4d6a-b9a7-2e4890f71356	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.10	600.00.601.00	Gratificaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3bd0c500-99ea-48eb-9471-97eff2d4f7c5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.11	600.00.601.00	Primas de antigüedad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
427dc2d7-0fbb-48b6-a2dd-9782aaeecf07	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.12	600.00.601.00	Aguinaldo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
867e750c-3476-4de2-8a0e-31ad0c83d6e1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.13	600.00.601.00	Indemnizaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dc332050-081c-4bf4-b035-6372afe26689	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.14	600.00.601.00	Destajo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
56f31701-41c0-403b-a4c0-6d5ff307cc33	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.15	600.00.601.00	Despensa	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
281974a1-4e93-448f-8c11-82ccaebe2f3f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.16	600.00.601.00	Transporte	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
da947543-13a3-478b-836c-b974c1d3efb2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.17	600.00.601.00	Servicio médico	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2a659a58-9987-4a3e-b86e-4ed88457cc0c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.18	600.00.601.00	Ayuda en gastos funerarios	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b3cbaaf3-45b8-4f1a-8135-f8959f86d440	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.19	600.00.601.00	Fondo de ahorro	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6917b501-6ba1-41f2-8e02-17520a8b69d4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.20	600.00.601.00	Cuotas sindicales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1bf1b509-8237-4373-a77e-c3364c5cfdb5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.21	600.00.601.00	PTU	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0379bf8d-4ee7-428a-8690-1c290c8ffa9b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.22	600.00.601.00	Estímulo al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fd4285fe-7619-4293-a3c3-a338c5868c05	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.23	600.00.601.00	Previsión social	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
382fa3c8-49bc-4607-a928-3653362d15a1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.24	600.00.601.00	Aportaciones para el plan de jubilación	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
70081171-0205-4c54-b29e-7493514b9639	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.25	600.00.601.00	Otras prestaciones al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c183d466-2fda-470d-9991-a75f88dcf297	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.26	600.00.601.00	Cuotas al IMSS	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0b9e3c83-0949-4c23-91e7-7343eb86ac57	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.27	600.00.601.00	Aportaciones al infonavit	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f0a4c43d-4de8-4cca-908c-3ed915808a10	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.28	600.00.601.00	Aportaciones al SAR	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0222c360-ca8f-429d-8f38-a4a19fdc4d47	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.29	600.00.601.00	Impuesto estatal sobre nóminas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cb84f976-2c61-4b9d-9d2c-bcc2a9e8c15f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.30	600.00.601.00	Otras aportaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
88b61e75-dfc4-47bc-aa63-bca195b3da03	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.31	600.00.601.00	Asimilados a salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f32f2894-a268-4d13-af5f-f002fb956d1d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.32	600.00.601.00	Servicios administrativos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c846a1dc-3210-4e45-9be6-bcb0b678165c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.33	600.00.601.00	Servicios administrativos partes relacionadas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
120c5c5f-daa9-4414-9dcb-e9a36ad86d5d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.34	600.00.601.00	Honorarios a personas físicas residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
edeed554-7342-484a-ac50-861a40b95c03	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.35	600.00.601.00	Honorarios a personas físicas residentes nacionales partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8c26e94f-63ab-4fd0-9fe7-e87e8be2e347	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.36	600.00.601.00	Honorarios a personas físicas residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1f9b955a-7704-43a5-b5f5-e0d6845beb96	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.37	600.00.601.00	Honorarios a personas físicas residentes del extranjero partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8b945f75-9a97-4131-8d88-4e82ae321931	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.38	600.00.601.00	Honorarios a personas morales residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2bbb5ff6-4c54-4f3e-b9ff-3b20b456e490	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.39	600.00.601.00	Honorarios a personas morales residentes nacionales partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1cf4c990-7f83-4078-b94f-82dcd169e3e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.40	600.00.601.00	Honorarios a personas morales residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c484c0fc-ee1e-45a8-9100-4d1c7a81f4b1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.41	600.00.601.00	Honorarios a personas morales residentes del extranjero partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
48a87c10-2648-420d-8b18-6be53059282e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.42	600.00.601.00	Honorarios aduanales personas físicas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
14a35146-b85c-423a-bf58-af2bacb3d47a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.43	600.00.601.00	Honorarios aduanales personas morales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ea64a97d-edea-4cb1-b6af-80bca5ec7cb1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.44	600.00.601.00	Honorarios al consejo de administración	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
74d8a618-fce8-473a-9cdf-60181e29728c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.45	600.00.601.00	Arrendamiento a personas físicas residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a4fb4b67-5869-40c7-a15e-3c0e198b6a7f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.46	600.00.601.00	Arrendamiento a personas morales residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d55a3377-d177-4790-a006-69b3671cc73e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.47	600.00.601.00	Arrendamiento a residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e67e00b0-c8b9-4a58-82ba-97d2d501f442	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.48	600.00.601.00	Combustibles y lubricantes	3	6	600	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1acccc38-d190-4823-be02-d0b5033c3b52	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.49	600.00.601.00	Viáticos y gastos de viaje	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e6b98498-11c9-42ca-8f4c-41b9c4f4d3ef	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.50	600.00.601.00	Teléfono, internet	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d77143cb-9067-4ca1-a3e2-36077b460fb8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.51	600.00.601.00	Agua	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
94464616-30bf-481f-b99f-04f71cbeb25b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.52	600.00.601.00	Energía eléctrica	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2722caa4-03af-4ff8-a74b-12cf7ac9a123	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.53	600.00.601.00	Vigilancia y seguridad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d6aef786-326c-4421-8a45-572a15223b67	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.54	600.00.601.00	Limpieza	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f2af1102-96fb-4eb1-bbfa-ad1ffdbe3dbe	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.55	600.00.601.00	Papelería y artículos de oficina	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3a98b552-1929-4fa3-ba32-ac6d75a72819	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.56	600.00.601.00	Mantenimiento y conservación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
72a31f65-a6bf-4973-9566-c6b50ded3820	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.57	600.00.601.00	Seguros y fianzas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6df617ff-2f4d-4f85-b196-8e3ce0374498	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.58	600.00.601.00	Otros impuestos y derechos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9fb42a1a-da25-4bd2-b56e-b98aa47b396d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.59	600.00.601.00	Recargos fiscales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6b10ff9b-6120-4ad8-a908-7335ea2833da	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.60	600.00.601.00	Cuotas y suscripciones	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
06cdf650-f807-456e-90a8-ef0f3c3af401	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.61	600.00.601.00	Propaganda y publicidad	3	6	620	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ac8266b6-bd20-47c9-bc59-cefa156b0c5b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.62	600.00.601.00	Capacitación al personal	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
da27df0b-865e-469b-9b08-c2d62313e7d5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.63	600.00.601.00	Donativos y ayudas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bbddddca-734f-4d58-ac45-c4a74e1ce9e9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.64	600.00.601.00	Asistencia técnica	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a761ae0f-4304-400e-9059-1da0f226af1f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.65	600.00.601.00	Regalías sujetas a otros porcentajes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6b0f1452-2bdb-454b-b015-ce28cf6c4a80	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.66	600.00.601.00	Regalías sujetas al 5%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8c55930a-bc10-408d-9f57-b57393cf75c3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.67	600.00.601.00	Regalías sujetas al 10%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c220c5a9-c28c-45a3-b6d9-ebf010ef66f2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.68	600.00.601.00	Regalías sujetas al 15%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ce935b25-31c8-44a0-a877-0772c5deef02	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.69	600.00.601.00	Regalías sujetas al 25%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
eca2f5b8-e314-47fe-af44-04e7e11f8f77	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.70	600.00.601.00	Regalías sujetas al 30%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f58b0ac2-e4ef-44a7-a77f-9c7dd4bc08f5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.71	600.00.601.00	Regalías sin retención	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ee1cae86-fb0b-4d83-9dcc-61af80d03e2b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.72	600.00.601.00	Fletes y acarreos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
098c3876-5ead-443b-8877-850d70dd1fa3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.73	600.00.601.00	Gastos de importación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9ef3fe74-ef9f-419f-8ffb-fefb828133f7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.74	600.00.601.00	Comisiones sobre ventas	3	6	620	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ecf03e8f-1311-4de0-ae2b-e52155bbd632	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.75	600.00.601.00	Comisiones por tarjetas de crédito	3	6	620	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
19a590d4-c7e6-4d7b-9ef3-10e97e0078c7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.76	600.00.601.00	Patentes y marcas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
33c3c8bf-82b2-4030-8beb-7633b0185c00	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.77	600.00.601.00	Uniformes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fd963b56-4e0c-429d-8823-5beb29c43776	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.78	600.00.601.00	Prediales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f3d5c3e4-8f99-4f3e-a644-aaaa79f3bb6f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.79	600.00.601.00	Gastos generales de urbanización	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a1bb6df2-6f2d-4735-a3f8-740d4c652b4a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.80	600.00.601.00	Gastos generales de construcción	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8bdc506a-ed3f-4a42-8eb7-7558b363a2b4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.81	600.00.601.00	Fletes del extranjero	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d0e60376-8ac8-41ae-9042-955a45128dff	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.82	600.00.601.00	Recolección de bienes del sector agropecuario y/o ganadero	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3b221997-a4a4-4913-82d7-97d6322ab3bd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.83	600.00.601.00	Gastos no deducibles (sin requisitos fiscales)	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
86562382-d635-499d-9394-db472ba1a2e8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.601.84	600.00.601.00	Otros gastos generales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
573452b9-1fb2-422c-8333-e002f32bd2ac	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.01	600.00.602.00	Sueldos y salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f209cc57-6d08-4c94-bcbb-69ae9d75991a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.02	600.00.602.00	Compensaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a97fd1bc-c1e8-46ab-8584-0c37d6d8df34	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.04	600.00.602.00	Premios de asistencia	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1772793b-4d80-45c5-8398-639c957c4725	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.05	600.00.602.00	Premios de puntualidad	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
21e3762e-9d1f-49ac-b9e7-0e074e3acdf3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.06	600.00.602.00	Vacaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fca9b6d9-e168-4da2-8531-2a736df06b8e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.07	600.00.602.00	Prima vacacional	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
93325738-186b-48ec-b784-f769126113a1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.08	600.00.602.00	Prima dominical	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5f943ce0-5df6-416d-94a5-bd36687a248f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.09	600.00.602.00	Días festivos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c19fbe1f-cfd8-481a-9b12-4100f4a1d383	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.10	600.00.602.00	Gratificaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
44b6774e-4df9-4689-8763-383547be31f4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.11	600.00.602.00	Primas de antigüedad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3a69721c-f8a0-40c8-8a47-2e70817f68e9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.12	600.00.602.00	Aguinaldo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e0b5d77a-e1c0-4599-956b-7d3fde12ccf2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.13	600.00.602.00	Indemnizaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
34d533bf-874a-4e6e-a85c-52aec7c01624	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.14	600.00.602.00	Destajo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a9d0ab1d-8925-4116-b1f6-f7561ea20328	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.15	600.00.602.00	Despensa	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d0ba9284-402e-4655-b0d2-8b7b6643ee99	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.16	600.00.602.00	Transporte	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a7e91926-3836-4e77-a201-3c058f4d198f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.17	600.00.602.00	Servicio médico	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f819ada5-7460-4ca4-a794-0a702a43dd70	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.18	600.00.602.00	Ayuda en gastos funerarios	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f5b3cda7-7a70-4e86-9040-8c2c63334748	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.19	600.00.602.00	Fondo de ahorro	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
02e52633-34d5-4402-af83-759bccf90bb3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.20	600.00.602.00	Cuotas sindicales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b978b620-5a6b-4f70-bc84-41007c262cf7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.21	600.00.602.00	PTU	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fe249952-aa81-4d9a-ac73-5ab65ac66e9b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.22	600.00.602.00	Estímulo al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
13382718-f1c1-4a73-97ec-896fdf285899	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.23	600.00.602.00	Previsión social	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
52310b17-7146-4305-880c-22bc81d9dc4c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.24	600.00.602.00	Aportaciones para el plan de jubilación	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
08aacda6-1001-45a4-9bca-97672c6240de	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.25	600.00.602.00	Otras prestaciones al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a5789f5f-0bb7-4bfa-bcf2-566254cca50e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.26	600.00.602.00	Cuotas al IMSS	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0e3d1a0e-2dcb-4a9b-a21d-d272b9466525	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.27	600.00.602.00	Aportaciones al infonavit	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4c6d4ba7-fa6a-43da-a438-5b2ad3855568	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.28	600.00.602.00	Aportaciones al SAR	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8e78fff4-75aa-4bec-9a8a-768341ded055	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.29	600.00.602.00	Impuesto estatal sobre nóminas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c3ffe7d0-0ffc-42dd-a78a-66b374a6b50f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.30	600.00.602.00	Otras aportaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
076205c9-b126-41c0-827f-caa407512ef2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.31	600.00.602.00	Asimilados a salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9fb38add-12df-48e6-8e53-2c87b5c17031	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.32	600.00.602.00	Servicios administrativos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
44ce6a04-258d-4a98-a8c7-732cdde9fe90	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.33	600.00.602.00	Servicios administrativos partes relacionadas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
13b9d22a-8b31-4021-a5f4-d5a30b42f25a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.34	600.00.602.00	Honorarios a personas físicas residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4a3ebf18-18b0-4b5b-895d-84dd61122f35	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.35	600.00.602.00	Honorarios a personas físicas residentes nacionales partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
27c3de10-245a-47b6-bfc2-458903fe768d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.36	600.00.602.00	Honorarios a personas físicas residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
275201ff-b733-4018-84d3-a82c66c812e7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.37	600.00.602.00	Honorarios a personas físicas residentes del extranjero partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e53887cd-92fe-41cd-9cf4-4cdef5d1cd0c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.38	600.00.602.00	Honorarios a personas morales residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6f2955a6-ca7b-4041-a8b1-b190c7d7645c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.39	600.00.602.00	Honorarios a personas morales residentes nacionales partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3db52ef4-a7af-4ff5-a152-97c688f490dc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.40	600.00.602.00	Honorarios a personas morales residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
579f5b2a-b34b-4885-868c-2b31cb09b1dc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.41	600.00.602.00	Honorarios a personas morales residentes del extranjero partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0ea5d4da-8e3e-4f9b-a597-a540ee8b9c1f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.42	600.00.602.00	Honorarios aduanales personas físicas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fd8217c3-390a-48d2-888f-1b4978b804b2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.43	600.00.602.00	Honorarios aduanales personas morales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
27dc1650-c43a-4c2c-af83-0593e5ed478b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.44	600.00.602.00	Honorarios al consejo de administración	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ac5f5dc7-afea-43cc-bb69-c0a306bc04b5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.45	600.00.602.00	Arrendamiento a personas físicas residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0c83ef49-64a2-4686-91db-150d2a61c6b3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.46	600.00.602.00	Arrendamiento a personas morales residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ca8c01a5-d6a2-48a7-891b-13bd4e4e9750	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.47	600.00.602.00	Arrendamiento a residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7f71d2b0-b0a4-4624-a0bb-e0f4a1418117	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.48	600.00.602.00	Combustibles y lubricantes	3	6	600	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
660e0da8-7f6e-4ceb-a9b2-b63bb9f16def	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.49	600.00.602.00	Viáticos y gastos de viaje	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4aa15f07-50db-44c4-baa5-18ce58618605	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.50	600.00.602.00	Teléfono, internet	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
735bc239-f955-4cce-aa50-68e6f67a36e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.51	600.00.602.00	Agua	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
98ceff14-a113-4db3-9159-a988c6667be0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.52	600.00.602.00	Energía eléctrica	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
34237836-3250-4bf5-a0e0-f0716ce62d63	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.53	600.00.602.00	Vigilancia y seguridad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b555d971-ee13-45b8-a256-811053b6105a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.54	600.00.602.00	Limpieza	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5f40a18f-4d83-4d15-b501-594797dfd5d2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.55	600.00.602.00	Papelería y artículos de oficina	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
766f50cb-9675-4461-a362-7f783710da6e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.56	600.00.602.00	Mantenimiento y conservación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
def3e4b2-44ed-4d6f-9066-e9bc91e38a34	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.57	600.00.602.00	Seguros y fianzas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
502e2582-7215-4c3a-84de-04cba7d328f3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.58	600.00.602.00	Otros impuestos y derechos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6e235fcd-6457-4e82-b248-0897a1c3cfb9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.59	600.00.602.00	Recargos fiscales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
71ba448a-3957-459f-99d7-39683923fac1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.60	600.00.602.00	Cuotas y suscripciones	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6a308ea5-02c4-4fc4-9687-2f878fe1913e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.61	600.00.602.00	Propaganda y publicidad	3	6	620	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6423f0d4-fe0a-46ac-aa14-9bd32f3f9c67	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.62	600.00.602.00	Capacitación al personal	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
96f30976-96cc-4d30-aa14-6836e1b55272	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.63	600.00.602.00	Donativos y ayudas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6cf2a2cc-a368-4179-978e-cca97bbacd9a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.64	600.00.602.00	Asistencia técnica	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cd4165d0-5b62-4f7b-abf6-f78294ce502b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.65	600.00.602.00	Regalías sujetas a otros porcentajes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9ad21762-7223-4f5a-963d-41373e4ae342	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.66	600.00.602.00	Regalías sujetas al 5%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
74149621-7428-4787-bf2d-1b677018791d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.67	600.00.602.00	Regalías sujetas al 10%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4c2900a4-b96e-41db-9007-35e66a365cc0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.68	600.00.602.00	Regalías sujetas al 15%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6422c13d-3df6-4e1e-8448-6f3e14909f63	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.69	600.00.602.00	Regalías sujetas al 25%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
32475e21-05e3-4d26-aa1e-55cea8db2176	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.70	600.00.602.00	Regalías sujetas al 30%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f4b60689-f5d6-4baa-ab51-8c035b2924ad	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.71	600.00.602.00	Regalías sin retención	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5451b837-355a-4612-99e0-c64b989c3235	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.72	600.00.602.00	Fletes y acarreos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
adfb49a5-9f94-4561-a64d-4b57883ea707	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.73	600.00.602.00	Gastos de importación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
095d7507-3149-47e9-9d85-94f6bc692396	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.74	600.00.602.00	Comisiones sobre ventas	3	6	620	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1e0fc296-2bd9-43a1-8b76-486b564ddeac	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.75	600.00.602.00	Comisiones por tarjetas de crédito	3	6	620	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
abf973eb-d350-44be-a851-897588ec353a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.76	600.00.602.00	Patentes y marcas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
31cb78da-83bc-41a5-9dc3-47273105f67f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.77	600.00.602.00	Uniformes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c0a34fcd-a76c-4179-a4ce-bc7a55495b5d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.78	600.00.602.00	Prediales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0da582f7-b761-4c12-b53c-8f156756e2b6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.79	600.00.602.00	Gastos de venta de urbanización	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3961c2df-87ad-4a5f-b8d2-2302f1890b8f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.80	600.00.602.00	Gastos de venta de construcción	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
17d5bfbe-29c0-408e-a2d7-aa93577f2e82	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.81	600.00.602.00	Fletes del extranjero	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ea8ecd26-4b24-4c5a-b571-9b6134109bec	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.82	600.00.602.00	Recolección de bienes del sector agropecuario y/o ganadero	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c3b03711-9e43-4119-8561-5d599a233d7e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.83	600.00.602.00	Gastos no deducibles (sin requisitos fiscales)	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2f9f20ff-d306-4371-ae77-9186a6de9e86	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.602.84	600.00.602.00	Otros gastos de venta	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e834efe5-4ac4-43a7-a866-09705dbba766	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.01	600.00.603.00	Sueldos y salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c53515dc-ae72-49f9-b27f-31778bcf0738	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.02	600.00.603.00	Compensaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ae514c54-e68a-416f-9bb0-a4177cf46079	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.03	600.00.603.00	Tiempos extras	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
418c407d-19bf-49fe-8359-f84d2328b49f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.04	600.00.603.00	Premios de asistencia	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9b3cb92d-e1fb-45fd-a1f0-c6db53b12e1f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.05	600.00.603.00	Premios de puntualidad	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8adb1f8b-518f-42aa-8e9f-fa3c4f7d4d10	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.06	600.00.603.00	Vacaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4f50b3d4-a889-4837-aa15-2abef141ba6e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.07	600.00.603.00	Prima vacacional	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9a582361-bc79-4be1-b674-4f8e54ad42b9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.08	600.00.603.00	Prima dominical	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
970883fb-9516-49f9-8db4-ea5e040b4cd5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.09	600.00.603.00	Días festivos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ed65bcaa-4563-4272-9539-31849b2983b1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.10	600.00.603.00	Gratificaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4594c4d3-4e37-4033-a7a5-03152d565af8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.11	600.00.603.00	Primas de antigüedad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
26ef73a2-b9b8-4e8b-bd35-413acad4c1a1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.12	600.00.603.00	Aguinaldo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
71a863a4-706d-4885-b49c-592f5c97c946	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.13	600.00.603.00	Indemnizaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f665cabb-7b69-41b4-bcbf-fc517b094634	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.14	600.00.603.00	Destajo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
82d072ad-a8d8-4eee-b1ae-84c33cc1a321	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.15	600.00.603.00	Despensa	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c2d410fe-2a19-409b-8ce7-c53c42969c0c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.16	600.00.603.00	Transporte	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8b66f832-a4a7-45a7-93bc-1ecccb6ec40e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.17	600.00.603.00	Servicio médico	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c25a94a1-1b16-48ab-bc7e-ceef0659a229	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.18	600.00.603.00	Ayuda en gastos funerarios	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b45459e5-422f-4f42-aee8-9174a4d4c26a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.19	600.00.603.00	Fondo de ahorro	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e31f2fb5-68a2-4024-b1f4-9a6f528fca73	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.20	600.00.603.00	Cuotas sindicales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0824ca69-c918-42d3-b9fa-aff635917613	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.21	600.00.603.00	PTU	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d04d425f-e2bb-468e-b3f2-c74448778704	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.22	600.00.603.00	Estímulo al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
68f2ecda-21e9-44ca-ba13-e79112df0c98	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.23	600.00.603.00	Previsión social	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dc426913-7493-41c7-bb32-cd3c36696cf6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.24	600.00.603.00	Aportaciones para el plan de jubilación	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a2eb5df3-d8c2-4215-aa7f-f8409c50f329	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.25	600.00.603.00	Otras prestaciones al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d1a9d62a-92c3-43bd-82a3-68586b1bf940	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.26	600.00.603.00	Cuotas al IMSS	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1b718b92-c36f-4b90-84c4-692664826be6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.27	600.00.603.00	Aportaciones al infonavit	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5d47f451-ec0c-4871-9397-1986288b90ec	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.28	600.00.603.00	Aportaciones al SAR	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f1068114-ba0b-43b2-9b4b-c47ee4be550c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.29	600.00.603.00	Impuesto estatal sobre nóminas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
44a83b9c-5933-44fb-9b5b-41efa8411257	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.30	600.00.603.00	Otras aportaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
88d05ead-aa95-42ac-9aea-c58557631a55	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.31	600.00.603.00	Asimilados a salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
22317968-e369-4e90-8e37-8fd0373510c7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.32	600.00.603.00	Servicios administrativos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
56e392ea-f57a-4c26-9e1a-4f1233fd5f2f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.33	600.00.603.00	Servicios administrativos partes relacionadas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9f22f793-f5f7-4605-b1b1-48e891b1bc29	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.34	600.00.603.00	Honorarios a personas físicas residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
97df020e-d993-4991-a151-01dfe17576c0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.35	600.00.603.00	Honorarios a personas físicas residentes nacionales partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ea54bf15-5a9f-462a-bb99-4ba94fe46658	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.36	600.00.603.00	Honorarios a personas físicas residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a9e450e0-5142-45fe-bfdf-148d85ff125e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.37	600.00.603.00	Honorarios a personas físicas residentes del extranjero partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6ffd629e-66dc-41a5-9fdf-d1ceb7c53638	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.38	600.00.603.00	Honorarios a personas morales residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
697c649a-d6fc-48e4-9408-6b1809bfa846	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.39	600.00.603.00	Honorarios a personas morales residentes nacionales partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
03657010-9e1c-463d-8eb2-1358cab41437	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.40	600.00.603.00	Honorarios a personas morales residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4579294f-801f-4f47-8a55-81645fd7ad31	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.41	600.00.603.00	Honorarios a personas morales residentes del extranjero partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d0fdcf19-a914-4c1c-bc61-77d264d074df	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.42	600.00.603.00	Honorarios aduanales personas físicas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d2066894-fb97-4705-878c-9fd33660eef9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.43	600.00.603.00	Honorarios aduanales personas morales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ab53d9f0-16f7-4cfc-a3bf-04a2703919d6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.44	600.00.603.00	Honorarios al consejo de administración	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c4fad020-a1ae-4363-a398-b6a1c8e63fbc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.45	600.00.603.00	Arrendamiento a personas físicas residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f11324c1-7948-429f-ac10-b4ebe67f2927	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.46	600.00.603.00	Arrendamiento a personas morales residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d9a3db2c-9000-4b5e-aa6a-6185c7505536	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.47	600.00.603.00	Arrendamiento a residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f8af8c69-4024-4b8f-88af-27f5e9622318	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.48	600.00.603.00	Combustibles y lubricantes	3	6	600	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a7ee1bb6-831a-47c2-823b-dedc7bbdadf1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.49	600.00.603.00	Viáticos y gastos de viaje	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f0f839c5-9011-41ce-ac1e-5aae0f5f8ebe	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.50	600.00.603.00	Teléfono, internet	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
159f381a-6141-462b-9ca7-e40207d63152	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.51	600.00.603.00	Agua	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7c320aa0-7d1f-44a9-94a8-efde7c0c4526	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.52	600.00.603.00	Energía eléctrica	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c0edd5ea-bbe8-4c4c-93f1-b3cb5b70219d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.53	600.00.603.00	Vigilancia y seguridad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
89709bff-01e2-492b-9daf-da00c5fa0beb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.54	600.00.603.00	Limpieza	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b2988794-4358-4fc1-8a55-8e39b9412782	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.55	600.00.603.00	Papelería y artículos de oficina	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cc21a47c-c0a6-4b6c-b1dd-adea1b454987	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.56	600.00.603.00	Mantenimiento y conservación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8aa7fa03-a0a4-4e78-9a57-406e729022e3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.57	600.00.603.00	Seguros y fianzas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f6fbffc2-ab1d-4e6b-b0e0-0af6ed9ea27d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.58	600.00.603.00	Otros impuestos y derechos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
be736b9e-238e-4962-847d-9899ae7d2d65	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.59	600.00.603.00	Recargos fiscales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e62bb1c7-c58b-420e-b265-324684765a03	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.60	600.00.603.00	Cuotas y suscripciones	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
83ab2f83-75a3-4628-86f0-27fd5d699d2c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.61	600.00.603.00	Propaganda y publicidad	3	6	620	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c85dfd5d-4388-45c8-ac4e-7047bbe08523	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.62	600.00.603.00	Capacitación al personal	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c70a71eb-8dba-438e-b2a8-091e453e65a3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.63	600.00.603.00	Donativos y ayudas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2138dce1-aeb0-47f3-82a2-2cac880a16bb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.64	600.00.603.00	Asistencia técnica	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e42e9751-e923-4c6b-b8e3-191cd2c9f95e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.65	600.00.603.00	Regalías sujetas a otros porcentajes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
668e3342-86ee-4b31-8014-80c15cf20104	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.66	600.00.603.00	Regalías sujetas al 5%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c531670d-31ba-459e-a757-8a63af5984cd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.67	600.00.603.00	Regalías sujetas al 10%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b4fb705d-ec1a-4290-8232-887edf76791c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.68	600.00.603.00	Regalías sujetas al 15%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4fd1ba87-20db-49c1-9077-30893f88760e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.69	600.00.603.00	Regalías sujetas al 25%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7ddd164c-10e7-4926-882c-d90d8fbd9f23	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.70	600.00.603.00	Regalías sujetas al 30%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bc472ffd-142e-475a-9731-ca036c82d250	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.71	600.00.603.00	Regalías sin retención	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b7e89c40-89f7-4c90-b69b-e90541ec9438	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.72	600.00.603.00	Fletes y acarreos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d2a40c2b-d227-41c2-ae49-1f17627325e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.73	600.00.603.00	Gastos de importación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e09d64d1-47d1-48b6-ab24-e260b9b17b6b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.74	600.00.603.00	Patentes y marcas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b33cba05-8400-43c6-98f7-d7cd624a0a03	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.75	600.00.603.00	Uniformes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
65a975ed-ab8d-47ac-b492-e059ef70b3d9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.76	600.00.603.00	Prediales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
94cd55f5-7f68-4f90-81b2-1f68b7fe14de	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.77	600.00.603.00	Gastos de administración de urbanización	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b350883e-6060-4c30-9b07-74847004aa24	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.78	600.00.603.00	Gastos de administración de construcción	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c3ffda67-4525-4048-a308-09750886a2f1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.79	600.00.603.00	Fletes del extranjero	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0472f02b-9112-4944-923d-c03f94efca0f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.80	600.00.603.00	Recolección de bienes del sector agropecuario y/o ganadero	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
77ef9b14-e2a4-4c87-b08e-900d87ccb30f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.81	600.00.603.00	Gastos no deducibles (sin requisitos fiscales)	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f7ed3001-fba9-40d5-aa37-9b1184c06351	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.603.82	600.00.603.00	Otros gastos de administración	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
059756a5-571a-411d-9c3f-990abc4815dc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.01	600.00.604.00	Sueldos y salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f1e73805-f64d-4e04-88ab-e594dde044e1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.02	600.00.604.00	Compensaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ade40b07-07ae-4ec2-a4f6-f0dfa38291ba	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.03	600.00.604.00	Tiempos extras	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2993d6b1-e0d6-4d1d-aad0-fcf7ba3dfcd2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.04	600.00.604.00	Premios de asistencia	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ad1ad572-6033-4c31-96f3-2f29e987b17d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.05	600.00.604.00	Premios de puntualidad	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9be42108-9e0d-4f16-b65e-b809793625b8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.06	600.00.604.00	Vacaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
94f00d35-ba26-4ac4-a037-e1ac79cdc9bd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.07	600.00.604.00	Prima vacacional	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
36301cee-d533-4681-9c46-c8d02eddac57	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.08	600.00.604.00	Prima dominical	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
881224d1-884e-4db3-8cf5-698332b5c56f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.09	600.00.604.00	Días festivos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
59b96418-f2fd-4f08-8a72-263c49f9d80e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.10	600.00.604.00	Gratificaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
771d54bd-e8b1-4f87-8b78-d15e948e5a57	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.11	600.00.604.00	Primas de antigüedad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6fe51f1b-9e8d-44fc-be5b-737f0cf79c6f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.12	600.00.604.00	Aguinaldo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c3e6df3e-4589-4481-8e0a-d471c35aa3bb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.13	600.00.604.00	Indemnizaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ed2ed994-ac5a-4b52-b2e0-0ec577353230	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.14	600.00.604.00	Destajo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
055362b7-8d0c-413d-a58d-36dbdd87b5bd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.15	600.00.604.00	Despensa	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
be595b0c-ea8c-4e44-bfd0-b4e89f1f65c9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.16	600.00.604.00	Transporte	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d00205ca-9318-4ad0-b2b4-5642a916086a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.17	600.00.604.00	Servicio médico	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ee5574f6-d0a0-4053-9217-3787d41c26cc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.18	600.00.604.00	Ayuda en gastos funerarios	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
79c65141-80fa-4b57-86dc-9c961d6eb516	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.19	600.00.604.00	Fondo de ahorro	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8c334bb5-af7a-48a5-855d-8b5041715106	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.20	600.00.604.00	Cuotas sindicales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c9b81683-83c0-4414-b641-df05f34859e2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.21	600.00.604.00	PTU	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
62b9e235-a714-410c-b327-49cae71d590a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.22	600.00.604.00	Estímulo al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f4469c87-ff1e-4f2f-b4eb-b7a63e5331c7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.23	600.00.604.00	Previsión social	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
654da9a0-25ff-4390-8bb4-12b271c0458b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.24	600.00.604.00	Aportaciones para el plan de jubilación	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f5be8864-7f8b-468e-b13c-245e652e5761	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.25	600.00.604.00	Otras prestaciones al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
149304ee-fc5b-4039-b116-8b6c6e5db0ee	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.26	600.00.604.00	Cuotas al IMSS	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
01752e53-6762-4668-8581-86d2f5dd62ba	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.27	600.00.604.00	Aportaciones al infonavit	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9e9a5872-5d89-4be7-beef-9a7e5ebdaa57	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.28	600.00.604.00	Aportaciones al SAR	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fa965742-71d1-4b1e-a118-16022538c0c5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.29	600.00.604.00	Impuesto estatal sobre nóminas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
23fa9503-a9ca-4f1e-ad27-87845266f74e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.30	600.00.604.00	Otras aportaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f2d146ce-9730-43da-9d8e-db7bd000a90a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.31	600.00.604.00	Asimilados a salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
21f6b593-19cd-43f9-81ce-3becb58e55a3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.32	600.00.604.00	Servicios administrativos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
584b173b-43bf-40b7-8474-3e9d89254708	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.33	600.00.604.00	Servicios administrativos partes relacionadas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b330aebe-5874-4c9a-b648-5372e6071da3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.34	600.00.604.00	Honorarios a personas físicas residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
003367e6-4777-4094-adfb-766c072eb7e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.35	600.00.604.00	Honorarios a personas físicas residentes nacionales partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3878205d-0a2a-4e46-997a-045957354745	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.36	600.00.604.00	Honorarios a personas físicas residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0d89a3f5-8a0e-493e-9356-4f26a73f4b9e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.37	600.00.604.00	Honorarios a personas físicas residentes del extranjero partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c8c7c294-117e-46a1-848d-7d6af5ea4ec6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.38	600.00.604.00	Honorarios a personas morales residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b94b795a-2f3b-4b98-8fd6-06ece0599227	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.39	600.00.604.00	Honorarios a personas morales residentes nacionales partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
db90839e-e1df-4260-80c0-4bb7fa50c827	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.40	600.00.604.00	Honorarios a personas morales residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
14aeeb21-5377-441d-b386-3af7b1a93cc4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.41	600.00.604.00	Honorarios a personas morales residentes del extranjero partes relacionadas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
81b74d12-2e9d-4a66-b22a-709906277def	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.42	600.00.604.00	Honorarios aduanales personas físicas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c8c0b014-ec4e-4643-9dd5-aa00e1196f81	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.43	600.00.604.00	Honorarios aduanales personas morales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0cf2d802-023b-48ce-aed6-b29e5f134ccf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.44	600.00.604.00	Honorarios al consejo de administración	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3912d738-c7db-4921-81a9-9e19faa0316d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.45	600.00.604.00	Arrendamiento a personas físicas residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a13ae565-a3ad-4d55-9523-18121507f772	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.46	600.00.604.00	Arrendamiento a personas morales residentes nacionales	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
29ed10b4-68b9-4a36-94ab-311b609ff5ec	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.47	600.00.604.00	Arrendamiento a residentes del extranjero	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f30daddb-5642-4e9f-a2fe-a947b9c70b9a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.48	600.00.604.00	Combustibles y lubricantes	3	6	600	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
26ef6510-ad4f-46d9-b3af-fd340a7a9022	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.49	600.00.604.00	Viáticos y gastos de viaje	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f97cc99f-269a-4983-b051-76daf00205ef	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.50	600.00.604.00	Teléfono, internet	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2ffbef0a-5f05-46da-b051-4339ad9d6c26	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.51	600.00.604.00	Agua	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c54c23b0-5c69-4344-8809-4a299bad5728	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.52	600.00.604.00	Energía eléctrica	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c1326e45-b6e7-457d-9ccb-4aed748a5197	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.53	600.00.604.00	Vigilancia y seguridad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
36dc1b9e-b53c-4ef3-8a3e-d13704c61fe0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.54	600.00.604.00	Limpieza	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a146d9bb-a3d7-4a3d-a65e-79f3f4c3c96c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.55	600.00.604.00	Papelería y artículos de oficina	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3555df6d-460f-4c82-9751-000d43a73fa7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.03	100.01.113.00	IETU a favor	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1b7242ea-81b0-4e1f-832c-eed52818d0f1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.56	600.00.604.00	Mantenimiento y conservación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d340c4eb-235a-4325-b6eb-f2014974fbf1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.57	600.00.604.00	Seguros y fianzas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c87a7cc7-3bd7-4f43-ad38-74219dc72c2b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.58	600.00.604.00	Otros impuestos y derechos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d6405da9-2533-4421-b77f-3c40743078d5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.59	600.00.604.00	Recargos fiscales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
eb29c30b-f82a-4e45-ae70-41a2d906df04	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.60	600.00.604.00	Cuotas y suscripciones	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b48e3b64-fd5e-43bb-b4b5-b436d5b64b62	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.61	600.00.604.00	Propaganda y publicidad	3	6	620	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9911c064-6773-429d-9753-d12ba603d068	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.62	600.00.604.00	Capacitación al personal	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
76413030-5b29-45f0-a8de-54ca281bf4aa	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.63	600.00.604.00	Donativos y ayudas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c26b836f-afdc-47a0-88a0-3f20050b33ac	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.64	600.00.604.00	Asistencia técnica	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d38a5e60-e1da-4645-81b5-85099488d152	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.65	600.00.604.00	Regalías sujetas a otros porcentajes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
52c9a23d-d8df-4298-a4d5-11192c185d44	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.66	600.00.604.00	Regalías sujetas al 5%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
70f7c17f-0bfd-4dd4-aa99-517189db3e98	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.67	600.00.604.00	Regalías sujetas al 10%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d91dddb1-929f-46b9-a279-5603c56f046a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.68	600.00.604.00	Regalías sujetas al 15%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8727aa98-5e3b-4af2-a783-4a811bc19f3d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.69	600.00.604.00	Regalías sujetas al 25%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8cc0f071-9dc5-441a-a46e-b93d81de9505	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.70	600.00.604.00	Regalías sujetas al 30%	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e769dbd4-7e05-419a-8dfb-4075d07a5199	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.71	600.00.604.00	Regalías sin retención	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fcb6f5e5-9858-43a0-8beb-96156d75d618	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.72	600.00.604.00	Fletes y acarreos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f2f1c768-8772-4a52-87ae-9f154da06dca	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.73	600.00.604.00	Gastos de importación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6829b5e0-8d4f-4e96-9841-7c26f618a362	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.74	600.00.604.00	Patentes y marcas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3a6e409d-60de-47a0-9ebc-23c3f36c771f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.75	600.00.604.00	Uniformes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2b1edb46-4706-4268-b5be-a25f95c19930	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.76	600.00.604.00	Prediales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
38ab12fa-d2a8-4a6f-b45e-50abcd19c8b3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.77	600.00.604.00	Gastos de fabricación de urbanización	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
28369b97-c3b4-422c-8008-1a2f1ba22139	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.78	600.00.604.00	Gastos de fabricación de construcción	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b2c24920-87a8-42df-a5a1-9bcffe262165	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.79	600.00.604.00	Fletes del extranjero	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7a9a9325-a8b9-4ec6-88ba-ea65320db6c0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.80	600.00.604.00	Recolección de bienes del sector agropecuario y/o ganadero	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b9ba13d0-e167-4d1b-b936-33d60f1d24f9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.81	600.00.604.00	Gastos no deducibles (sin requisitos fiscales)	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
916edba1-6570-4086-b275-7a2d1cc6404d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.604.82	600.00.604.00	Otros gastos de fabricación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
adcd3b28-8fcc-43cb-82ed-a9566e48fed8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.01	600.00.000.00	Mano de obra	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5affcfe2-d7f7-4ee1-9f4d-5c29f923565c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.02	600.00.000.00	Sueldos y Salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
70f0285b-4b7b-475f-b934-c3dd15acbc62	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.03	600.00.000.00	Compensaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
91487c4e-6060-41fb-b601-ff01f85eb614	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.04	600.00.000.00	Tiempos extras	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3b9e1ceb-0068-402c-91c9-eea546534c89	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.05	600.00.000.00	Premios de asistencia	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1af76e03-b78d-46c3-a0a6-c6675babc95c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.06	600.00.000.00	Premios de puntualidad	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f5a9ec54-bfd0-4972-9175-f352d8a95e58	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.07	600.00.000.00	Vacaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4c36f234-e5e9-465e-8ec0-87cd0e3f7e44	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.08	600.00.000.00	Prima vacacional	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1dba328c-84ee-4879-b7e2-fdb04da3ca1d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.09	600.00.000.00	Prima dominical	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f4f0ac24-62a9-4be5-a0e2-a15832ffd802	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.10	600.00.000.00	Días festivos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7194c760-12a1-452d-8f6f-4d27202161d8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.11	600.00.000.00	Gratificaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4c480015-c0ef-45dd-9b83-bd0b615c2dc1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.12	600.00.000.00	Primas de antigüedad	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a5cf035f-96ba-4a07-bd18-50d58d5c1139	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.13	600.00.000.00	Aguinaldo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fe88bf5e-326c-4cc3-ac5e-1079cfa8360e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.14	600.00.000.00	Indemnizaciones	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
11b19a3b-1d19-4d30-86ce-433d472f161a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.15	600.00.000.00	Destajo	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
82153c0f-6757-487a-8c27-4879925781d2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.16	600.00.000.00	Despensa	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d367a10b-e20f-41f2-92ad-70382280b36f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.17	600.00.000.00	Transporte	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a046ba9d-60e9-4f28-9286-f96f025d4fbf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.18	600.00.000.00	Servicio médico	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8eb4c7f7-f263-422b-ab2b-e4d53d6e59bd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.19	600.00.000.00	Ayuda en gastos funerarios	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
588c0375-fcfd-4937-a3b9-44211d89fd44	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.20	600.00.000.00	Fondo de ahorro	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6ed5b015-dba4-415a-8375-aee95bb38c0e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.21	600.00.000.00	Cuotas sindicales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9bfacc94-acb9-4555-9233-6880cc2800a3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.22	600.00.000.00	PTU	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c1f65263-b263-4285-adf7-23859ac3a7bb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.23	600.00.000.00	Estímulo al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0a58d791-2b84-4ebe-9093-24c4f79393b5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.24	600.00.000.00	Previsión social	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
af4f46f9-bf52-4b61-9c15-b2d01881ad74	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.25	600.00.000.00	Aportaciones para el plan de jubilación	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b2f54574-0e73-44b4-bea3-21f38a0c521d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.26	600.00.000.00	Otras prestaciones al personal	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1c618fe6-54cc-47bb-84fb-641d56ccd091	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.27	600.00.000.00	Asimilados a salarios	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
56ea40aa-89da-4085-a2fe-ee035ee60bf0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.28	600.00.000.00	Cuotas al IMSS	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a2844ba4-2f61-498d-8cdf-8f2b3d95996d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.29	600.00.000.00	Aportaciones al infonavit	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
de69116a-6e0a-4542-a0bf-ca484a6d1d7b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.30	600.00.000.00	Aportaciones al SAR	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
93406cc7-908c-498e-ad1c-4e0be18e7f4d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.605.31	600.00.000.00	Otros costos de mano de obra directa	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f1640b25-1463-48f6-a0ae-961aa819c682	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.606.01	600.00.606.00	Facilidades administrativas fiscales	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d87f6dca-9b41-4030-b400-22d7bd656cb2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.607.01	600.00.607.00	Participación de los trabajadores en las utilidades	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1b85e3eb-c1ef-4c1c-b517-87808ea07c3c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.608.01	600.00.608.00	Participación en resultados de subsidiarias	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
95f1746e-5c47-40bf-a7bb-203f6fa548de	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.609.01	600.00.609.00	Participación en resultados de asociadas	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c097540b-6fd6-4ae1-b029-201d7caf1632	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.610.01	600.00.610.00	Participación de los trabajadores en las utilidades diferida	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
05f45c35-bb2d-4714-940c-6376c21b7d8b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.611.01	600.00.611.00	Impuesto Sobre la renta	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2cd950ea-4d1e-4132-afd8-5f98741db636	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.611.02	600.00.611.00	Impuesto Sobre la renta por remanente distribuible	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5abed65a-07a2-4a14-8909-11392ac1b038	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.612.01	600.00.612.00	Gastos no deducibles para CUFIN	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
42c8a784-9db8-426e-81a3-6ea8151e3e6c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.01	600.00.613.00	Depreciación de edificios	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b823c0d2-99f5-4629-902c-08ac7800122a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.02	600.00.613.00	Depreciación de maquinaria y equipo	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7675c0f4-7b18-4e10-a551-2c2013251ce9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.03	600.00.613.00	Depreciación de automóviles, autobuses, camiones de carga, tractocamiones, montacargas y remolques	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1560d8eb-ddd6-495f-b169-70a494b7b637	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.04	600.00.613.00	Depreciación de mobiliario y equipo de oficina	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
304d5dee-9f05-41fd-9af7-7a8e0fb3563e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.05	600.00.613.00	Depreciación de equipo de cómputo	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
205cbe22-ad4e-4590-b077-896337b09864	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.06	600.00.613.00	Depreciación de equipo de comunicación	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a096f717-c5e7-4e7a-b682-c4bcf899888f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.07	600.00.613.00	Depreciación de activos biológicos, vegetales y semovientes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
33f087b2-b742-403f-a17a-4b25cdd9c9a9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.08	600.00.613.00	Depreciación de otros activos fijos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0c6aa9b8-d328-469d-95bc-556bc184e831	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.09	600.00.613.00	Depreciación de ferrocarriles	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
737ce56b-5296-44b7-bc68-ac4e28eb69e9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.10	600.00.613.00	Depreciación de embarcaciones	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
56367900-cd35-42ab-8305-1f635a7ddd77	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.11	600.00.613.00	Depreciación de aviones	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
38ebcf61-d7b7-434d-95f3-037328e4a6c5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.12	600.00.613.00	Depreciación de troqueles, moldes, matrices y herramental	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
093f2322-9325-4727-b733-1733b4a88ee6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.13	600.00.613.00	Depreciación de equipo de comunicaciones telefónicas	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
811cff89-ad25-4837-9a7c-2224cecb4c04	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.14	600.00.613.00	Depreciación de equipo de comunicación satelital	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
329cfc7d-c2fc-4e62-946c-622c899cd434	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.15	600.00.613.00	Depreciación de equipo de adaptaciones para personas con capacidades diferentes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dc063459-b5fa-4c20-be0c-44fa570baa00	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.16	600.00.613.00	Depreciación de maquinaria y equipo de generación de energía de fuentes renovables o de sistemas de cogeneración de electricidad eficiente	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f900c542-4af8-42f8-a392-2734d06124e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.17	600.00.613.00	Depreciación de adaptaciones y mejoras	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
88c325c6-aa6f-4925-95fd-686ac13c9afe	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.613.18	600.00.613.00	Depreciación de otra maquinaria y equipo	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6b7cfdfb-b287-4404-aa42-de42b4fe0811	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.01	600.00.614.00	Amortización de gastos diferidos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d771db69-2d0f-42b7-85be-ad5508b5beda	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.02	600.00.614.00	Amortización de gastos pre operativos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4697879c-9430-4dd9-a11d-f83653291656	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.03	600.00.614.00	Amortización de regalías, asistencia técnica y otros gastos diferidos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
922fb640-57dd-44ef-ab48-87070cb40e91	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.04	600.00.614.00	Amortización de activos intangibles	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1526b1cd-a807-4474-a35a-d71fa9408b17	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.05	600.00.614.00	Amortización de gastos de organización	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c945f484-8453-4b0e-bb54-f63049ed7249	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.06	600.00.614.00	Amortización de investigación y desarrollo de mercado	3	6	610	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0bcacd40-df58-4985-bdf6-7ba59fd3a153	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.07	600.00.614.00	Amortización de marcas y patentes	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e160ec1d-b56a-407a-94fd-e640a3c7d1a9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.08	600.00.614.00	Amortización de crédito mercantil	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7b643b46-f3d8-4e56-a8f0-6ef9ef06014e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.09	600.00.614.00	Amortización de gastos de instalación	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
97896018-7226-4040-afbe-9001f4a185bc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	600.00.614.10	600.00.614.00	Amortización de otros activos diferidos	3	6	699	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7bd22fe0-a38c-456f-ac7e-8dfd22e9027f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.01	700.00.701.00	Pérdida cambiaria	3	6	4321	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2ac62894-baa8-4cf8-b134-a36e1175d54d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.02	700.00.701.00	Pérdida cambiaria nacional parte relacionada	3	6	4321	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
457e1068-d817-4963-8c0d-14df5b7f83a2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.03	700.00.701.00	Pérdida cambiaria extranjero parte relacionada	3	6	4321	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4a2087d9-b433-4688-8b3b-8fe68407e13f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.04	700.00.701.00	Intereses a cargo bancario nacional	3	6	4311	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6fe935c6-287b-4d8f-af69-31a78a6f8de4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.05	700.00.701.00	Intereses a cargo bancario extranjero	3	6	4311	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7c579028-69c7-4b56-a947-615651a89b78	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.06	700.00.701.00	Intereses a cargo de personas físicas nacional	3	6	4311	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
331d214a-3c0e-4470-8fc6-cc28899ae40c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.07	700.00.701.00	Intereses a cargo de personas físicas extranjero	3	6	4311	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
77d475ac-9978-4068-b064-35f8b288b707	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.08	700.00.701.00	Intereses a cargo de personas morales nacional	3	6	4311	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b0af8723-7c7c-4c98-ade5-37491e12c7a0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.09	700.00.701.00	Intereses a cargo de personas morales extranjero	3	6	4311	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bca504e9-87c6-44a4-a7b5-c3c558c80eb8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.10	700.00.701.00	Comisiones bancarias	3	6	4341	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1fd033c0-78ea-42c1-a120-9da2deb5bd93	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.701.11	700.00.701.00	Otros gastos financieros	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b8e23409-39ca-4ae1-bd17-258c41f73d07	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.01	700.00.702.00	Utilidad cambiaria	3	4	4320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a4fbe29a-a70f-4f6f-8c93-3c9949c32dc6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.02	700.00.702.00	Utilidad cambiaria nacional parte relacionada	3	4	4320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a557299d-f021-4e77-a124-396eed84a312	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.03	700.00.702.00	Utilidad cambiaria extranjero parte relacionada	3	4	4320	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fb310ba0-b0d0-41dc-86af-d4df2ebc8b15	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.04	700.00.702.00	Intereses a favor bancarios nacional	3	4	4310	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
914a1b61-b760-4657-9f73-c7970bb0f6e0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.05	700.00.702.00	Intereses a favor bancarios extranjero	3	4	4310	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2e88d4f8-d026-41fa-9ba8-828ab906018e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.06	700.00.702.00	Intereses a favor de personas físicas nacional	3	4	4310	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f8c471f4-74ab-41ca-a0de-0b34cbc0c597	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.07	700.00.702.00	Intereses a favor de personas físicas extranjero	3	4	4310	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3013dd80-b451-4e1c-8036-e4ab03ddbab2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.08	700.00.702.00	Intereses a favor de personas morales nacional	3	4	4310	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2c819c60-6cd0-4d1b-b703-32a4c5c4af08	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.09	700.00.702.00	Intereses a favor de personas morales extranjero	3	4	4310	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2b3c08f2-e935-44b8-be2a-d929697bd253	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.702.10	700.00.702.00	Otros productos financieros	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7937d99b-044a-4629-9dd4-e9bf49a44148	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.01	700.00.703.00	Pérdida en venta y/o baja de terrenos	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
07c62a54-8600-43ba-83c4-7fd6bfe7534d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.02	700.00.703.00	Pérdida en venta y/o baja de edificios	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c647f328-febf-4396-ae1e-fae5fa848b05	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.03	700.00.703.00	Pérdida en venta y/o baja de maquinaria y equipo	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
013a4b52-557f-461a-8635-d6e1963dab82	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.04	700.00.703.00	Pérdida en venta y/o baja de automóviles, autobuses, camiones de carga, tractocamiones, montacargas y remolques	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d89eca29-d59f-46e1-b7ba-b7c3583ce454	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.05	700.00.703.00	Pérdida en venta y/o baja de mobiliario y equipo de oficina	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b481e364-5025-448c-94e9-d83c31ff1a68	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.06	700.00.703.00	Pérdida en venta y/o baja de equipo de cómputo	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cd178a57-f813-405e-85f3-9373216860ae	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.07	700.00.703.00	Pérdida en venta y/o baja de equipo de comunicación	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
90c8125e-56df-423d-be90-410bfcd3ca3c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.08	700.00.703.00	Pérdida en venta y/o baja de activos biológicos, vegetales y semovientes	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9b3e0b10-f19d-4d83-b2d3-4409d5c4cd94	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.09	700.00.703.00	Pérdida en venta y/o baja de otros activos fijos	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7a33a0f2-5197-47ba-acb8-a329f3382e04	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.10	700.00.703.00	Pérdida en venta y/o baja de ferrocarriles	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3ad13e99-d3c9-491d-8b39-877e9280d143	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.11	700.00.703.00	Pérdida en venta y/o baja de embarcaciones	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fa100d30-7782-4c10-9771-b2122297434e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.12	700.00.703.00	Pérdida en venta y/o baja de aviones	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
56dd2c10-06c2-4a06-80b0-491066646a92	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.13	700.00.703.00	Pérdida en venta y/o baja de troqueles, moldes, matrices y herramental	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2576be2c-4014-4a00-bb55-c6ed5e5f7c00	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.14	700.00.703.00	Pérdida en venta y/o baja de equipo de comunicaciones telefónicas	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
872801d4-89ee-4374-8d02-210526917d87	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.15	700.00.703.00	Pérdida en venta y/o baja de equipo de comunicación satelital 703.16	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2347f7b7-5273-4df1-9207-520109310ee0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.16	700.00.703.00	Pérdida en venta y/o baja de equipo de adaptaciones para personas con capacidades diferentes	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
243bac53-e65e-4893-a541-2006f2b8c88a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.17	700.00.703.00	Pérdida en venta y/o baja de maquinaria y equipo de generación de energía de fuentes renovables o de sistemas de cogeneración de electricidad eficiente	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b6adbb2a-66b3-40d5-8426-c2420432ed32	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.18	700.00.703.00	Pérdida en venta y/o baja de otra maquinaria y equipo	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
255c2e54-4a9c-4e09-a0bd-04d4878b4573	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.19	700.00.703.00	Pérdida por enajenación de acciones	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8eb95bc7-2b4a-4164-980c-6877990703f7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.20	700.00.703.00	Pérdida por enajenación de partes sociales	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fc9c0861-3209-49d6-814d-fc6aa45a2b1b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.703.21	700.00.703.00	Otros gastos	3	6	4391	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
40e1cb57-b577-46bf-b1ad-726011c71f9e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.01	700.00.704.00	Ganancia en venta y/o baja de terrenos	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
44fba33c-b5af-44c9-ad4e-d15e682b6915	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.02	700.00.704.00	Ganancia en venta y/o baja de edificios	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
939beced-976d-4955-93ce-1ee23c724b69	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.03	700.00.704.00	Ganancia en venta y/o baja de maquinaria y equipo	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bb3ca6b5-f18d-445d-bfcc-d4a388179356	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.04	700.00.704.00	Ganancia en venta y/o baja de automóviles, autobuses, camiones de carga, tractocamiones, montacargas y remolques	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a77f1863-eb5c-4c66-82c6-0f669df23082	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.05	700.00.704.00	Ganancia en venta y/o baja de mobiliario y equipo de oficina	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
02a7519f-c8e2-4a68-9033-31b48dc78a89	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.06	700.00.704.00	Ganancia en venta y/o baja de equipo de cómputo	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
32e5c4c3-dc77-4827-b64f-628735e92a71	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.07	700.00.704.00	Ganancia en venta y/o baja de equipo de comunicación	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8a9f32b7-75d2-40ac-aba2-b8ceb88a2c64	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.08	700.00.704.00	Ganancia en venta y/o baja de activos biológicos, vegetales y semovientes	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b1e2c7ea-bce4-46fe-a905-bb94589aa92d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.09	700.00.704.00	Ganancia en venta y/o baja de otros activos fijos	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4c76de73-d623-474a-9108-4c138518223b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.10	700.00.704.00	Ganancia en venta y/o baja de ferrocarriles	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8247b49b-dfb0-4055-b59c-0c665e2d0f09	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.11	700.00.704.00	Ganancia en venta y/o baja de embarcaciones	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0f7a0fa9-06e7-4ab1-b901-c929639a2a9a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.12	700.00.704.00	Ganancia en venta y/o baja de aviones	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
66b9a56a-52fe-4c5c-8a16-9cb71746d17b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.13	700.00.704.00	Ganancia en venta y/o baja de troqueles, moldes, matrices y herramental	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c2add689-4e78-448e-860c-e3d2eaa67d29	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.14	700.00.704.00	Ganancia en venta y/o baja de equipo de comunicaciones telefónicas	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1f6ecd56-07c6-49b5-b346-0df3ab01c462	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.15	700.00.704.00	Ganancia en venta y/o baja de equipo de comunicación satelital	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
169d5bc9-5ed8-41b2-b090-2835dba4088f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.16	700.00.704.00	Ganancia en venta y/o baja de equipo de adaptaciones para personas con capacidades diferentes	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a3000fb5-9d03-418f-8396-d8ddfba9601c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.17	700.00.704.00	Ganancia en venta de maquinaria y equipo de generación de energía de fuentes renovables o de sistemas de cogeneración de electricidad eficiente	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a8162bba-200e-4e8e-b1bc-0ece1a5adeb6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.18	700.00.704.00	Ganancia en venta y/o baja de otra maquinaria y equipo	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9ea72844-ae92-4ca3-9d51-7ed4cc9c17e5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.19	700.00.704.00	Ganancia por enajenación de acciones	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c2bae0a2-8b12-4aab-99e7-00b64e1da04f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.20	700.00.704.00	Ganancia por enajenación de partes sociales	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
36ffa737-6c81-4256-95e2-b9c70e086d31	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.21	700.00.704.00	Ingresos por estímulos fiscales	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e6bf483e-2fa9-4200-9188-0607ca8af4b5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.22	700.00.704.00	Ingresos por condonación de adeudo	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
12f0d875-c660-4a7b-9933-cb760a4394e7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	700.00.704.23	700.00.704.00	Otros productos	3	4	4390	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6f5e6876-50e6-4b08-891a-0ed9c6e17069	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.801.01	800.00.801.00	UFIN	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
81b8e095-b627-4866-9764-71a2bd726515	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.801.02	800.00.801.00	Contra cuenta UFIN	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
764f2bb6-8f51-4e0f-9248-9d904fab20b7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.802.01	800.00.802.00	CUFIN	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b7baaa5d-9731-44c2-b53e-8ad060def5e9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.802.02	800.00.802.00	Contra cuenta CUFIN	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4838b542-9d54-4f59-a0ee-d72e44253bfd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.803.01	800.00.803.00	CUFIN de ejercicios anteriores	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fa08618b-6666-4fc5-8231-784b2370f9c4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.803.02	800.00.803.00	Contra cuenta CUFIN de ejercicios anteriores	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dce0d359-2be7-4c21-8e38-0dcc87fad490	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.804.01	800.00.804.00	CUFINRE	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d828aeee-e860-4ff0-8b26-894a1a70b34d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.804.02	800.00.804.00	Contra cuenta CUFINRE	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
54f37661-04b6-48ab-8c40-0b3eae8cb1bd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.805.01	800.00.805.00	CUFINRE de ejercicios anteriores	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3eeb0be8-e8f1-43d6-9ec9-af00104d36c4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.805.02	800.00.805.00	Contra cuenta CUFINRE de ejercicios anteriores	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9040e884-0e43-4e57-865f-20680f7b9f47	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.806.01	800.00.806.00	CUCA	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3adb17ec-83fc-4c6e-8686-b5665c67d73b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.806.02	800.00.806.00	Contra cuenta CUCA	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f3e25b13-56e6-4c2d-8a8c-9898e4ea1b00	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.807.01	800.00.807.00	CUCA de ejercicios anteriores	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
33681b91-4ed0-4ff2-b4f7-89d97eb5132c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.807.02	800.00.807.00	Contra cuenta CUCA de ejercicios anteriores	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f11fe4e7-3cc0-4759-9481-c736e1bd7feb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.808.01	800.00.808.00	Ajuste anual por inflación acumulable	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e25ee0e3-ec3e-44dc-a2a0-b1bd7e73a940	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.808.02	800.00.808.00	Acumulación del ajuste anual inflacionario	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
042e6bd4-30bf-47c0-82c9-4d0a562b4dfd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.809.01	800.00.809.00	Ajuste anual por inflación deducible	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
941c8c6e-ec6c-4808-be27-ab0712770f7e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.809.02	800.00.809.00	Deducción del ajuste anual inflacionario	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a067f301-4d5e-4963-8c03-d7123d526dd6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.810.01	800.00.810.00	Deducción de inversión	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
50ece025-6c1c-4029-8bc5-62979af2e04a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.810.02	800.00.810.00	Contra cuenta deducción de inversiones	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
528a454f-aabf-4f40-a7ab-903f1308e3bb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.811.01	800.00.811.00	Utilidad o pérdida fiscal en venta y/o baja de activo fijo	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
778e8316-925a-474d-9a0a-1e2522a78960	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.811.02	800.00.811.00	Contra cuenta utilidad o pérdida fiscal en venta y/o baja de activo fijo	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3e489270-d9f4-4475-b086-7ae4610def25	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.812.01	800.00.812.00	Utilidad o pérdida fiscal en venta acciones o partes sociales	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2cf0ce47-4346-40bd-81b8-6f85d7470dfc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.812.02	800.00.812.00	Contra cuenta utilidad o pérdida fiscal en venta acciones o partes sociales	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bd47f44e-a930-4059-a938-cc25536435bf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.813.01	800.00.813.00	Pérdidas fiscales pendientes de amortizar actualizadas de ejercicios anteriores	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
26c1e12d-0b95-42c9-9eae-56960f47c1ff	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.813.02	800.00.813.00	Actualización de pérdidas fiscales pendientes de amortizar de ejercicios anteriores	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c0f10763-cae9-4574-91ef-b3b1bb298979	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.814.01	800.00.814.00	Mercancías recibidas en consignación	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7b4ffcb0-0148-45fe-a3af-62265aa47150	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.814.02	800.00.814.00	Consignación de mercancías recibidas	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
59e0857d-92ef-425c-b52f-0c6a7095561e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.815.01	800.00.815.00	Crédito fiscal de IVA e IEPS por la importación de mercancías	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d71c13f0-a928-4e7d-af84-923dc3ff1433	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.815.02	800.00.815.00	Importación de mercancías con aplicación de crédito fiscal de IVA e IEPS	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
79c969bd-1dfc-4bc9-b9c9-bfb62f5a179b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.816.01	800.00.814.00	Crédito fiscal de IVA e IEPS por la importación de activo fijo	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0c0bfa64-56a3-456c-9db9-86cd6916eba5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.816.02	800.00.814.00	Importación de activo fijo con aplicación de crédito fiscal de IVA e IEPS	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
48de23cc-c4c8-4dcc-8c26-3af5596b1a2b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.817.01	800.00.815.00	Otras cuentas de orden	3	7	700	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bffef7e2-6b65-4080-9c61-d6df7eba983b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	800.00.817.02	800.00.815.00	Contra cuenta otras cuentas de orden	3	7	800	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a93c24c3-65cf-4770-b0da-b32c706a4491	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.101.01	100.01.101.00	Caja y efectivo	4	1	100	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d521833d-e84a-46cc-bc20-a1c647559d12	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.102.01	100.01.102.00	Bancos nacionales	4	1	101	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c146a049-2e41-4220-955f-072eaff80b00	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.102.02	100.01.102.00	Bancos extranjeros	4	1	101	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
df5e3230-e2e6-450d-8035-c1c89f20e214	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.103.01	100.01.103.00	Inversiones temporales	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
24b86609-8e62-4852-972f-98727c178ac5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.103.02	100.01.103.00	Inversiones en fideicomisos	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e957f434-5016-4447-b116-2735bf1397ba	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.103.03	100.01.103.00	Otras inversiones	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ad2107a5-8cd7-4d11-943a-fa0116d68108	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.104.01	100.01.104.00	Otros instrumentos financieros	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e7b61273-1a0c-4b10-99ff-6ff074b6e81a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.105.01	100.01.105.00	Clientes nacionales	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9cbcb479-9a6e-42e5-bd15-5f66fcffaea7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.105.02	100.01.105.00	Clientes extranjeros	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
071afcb6-63df-4b76-b73c-a79dd9d12a4e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.105.03	100.01.105.00	Clientes nacionales parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6f15edd2-2b8c-4804-b0ff-c09165be63c0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.105.04	100.01.105.00	Clientes extranjeros parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
095f7a3a-c640-4407-a81d-c53fd3ad5c74	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.01	100.01.106.00	Cuentas y documentos por cobrar a corto plazo nacional	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3ea10b29-d1b9-4844-913a-71cdd9c4fca4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.02	100.01.106.00	Cuentas y documentos por cobrar a corto plazo extranjero	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
842ac1ae-2f1c-4c98-ae4f-39735af3a84c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.03	100.01.106.00	Cuentas y documentos por cobrar a corto plazo nacional parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f2a13de4-a9a4-4248-a475-0089fb736048	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.04	100.01.106.00	Cuentas y documentos por cobrar a corto plazo extranjero parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fcfd1a24-7666-4d6e-8635-2e5e00d173cc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.05	100.01.106.00	Intereses por cobrar a corto plazo nacional	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
af13b36b-9a31-498c-86d8-0c8fc1a029eb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.06	100.01.106.00	Intereses por cobrar a corto plazo extranjero	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d0162ec6-657b-4e9d-bb8e-7b74135e2a42	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.07	100.01.106.00	Intereses por cobrar a corto plazo nacional parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
30e7c896-604d-4a3d-a4f5-69ac672b00c2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.08	100.01.106.00	Intereses por cobrar a corto plazo extranjero parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2a7331a6-806a-4f4a-b232-56095ff2b850	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.09	100.01.106.00	Otras cuentas y documentos por cobrar a corto plazo	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
60aa533e-64a3-41ae-b685-3eb6e810cd69	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.106.10	100.01.106.00	Otras cuentas y documentos por cobrar a corto plazo parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2a6dff12-4a3f-4be8-8566-e0c28ff8047f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.107.01	100.01.107.00	Funcionarios y empleados	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f03e2f28-f331-4727-b16c-e4b0089ab03a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.107.02	100.01.107.00	Socios y accionistas	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c8a4d3c1-4033-4229-ba8d-409e5c017c7f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.107.03	100.01.107.00	Partes relacionadas nacionales	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e35373d6-77a4-4dd0-a056-c3974e3da5c2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.107.04	100.01.107.00	Partes relacionadas extranjeros	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
47b6fd01-7870-4793-af4b-8e94edace306	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.107.05	100.01.107.00	Otros deudores diversos	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
43c1446f-7643-4e7c-9246-1bf0eaadc51a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.108.01	100.01.108.00	Estimación de cuentas incobrables nacional	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
46eb238a-61bc-4d0e-aae7-b358c51b44a7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.108.02	100.01.108.00	Estimación de cuentas incobrables extranjero	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c3c5c728-5936-4f36-b601-cad009dead99	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.108.03	100.01.108.00	Estimación de cuentas incobrables nacional parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
91a96d59-c90c-4d8f-ba09-16d707a49bc6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.108.04	100.01.108.00	Estimación de cuentas incobrables extranjero parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0e788609-9577-4446-a0ab-cd1c9ce4c0b6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.01	100.01.109.00	Seguros y fianzas pagados por anticipado nacional	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9e8a8ce2-32ce-4e8c-bddd-c2f5f5e9fb1b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.02	100.01.109.00	Seguros y fianzas pagados por anticipado extranjero	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
971dadc9-8bd2-4be6-a9dc-cbbcdded1899	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.03	100.01.109.00	Seguros y fianzas pagados por anticipado nacional parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1abc0943-5ae9-460d-b151-9727d3d93811	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.04	100.01.109.00	Seguros y fianzas pagados por anticipado extranjero parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d6670e8b-f4df-4c0c-800c-82972acf6854	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.05	100.01.109.00	Rentas pagados por anticipado nacional	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
94dd2178-b2b2-4255-b918-aa5ff8c79599	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.06	100.01.109.00	Rentas pagados por anticipado extranjero	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
30b2fcb3-f10e-4128-8abc-d46fb0752bb8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.07	100.01.109.00	Rentas pagados por anticipado nacional parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ca440365-aba6-40fc-a147-db5a5756be2c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.08	100.01.109.00	Rentas pagados por anticipado extranjero parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4ab2640a-344e-4cf1-bbff-042e111e7fe2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.09	100.01.109.00	Intereses pagados por anticipado nacional	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f5559903-1679-4c42-b2e7-5a838dc23f11	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.10	100.01.109.00	Intereses pagados por anticipado extranjero	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9c19360e-e002-4e5b-abe1-94c282bf0558	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.11	100.01.109.00	Intereses pagados por anticipado nacional parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ee25dc39-36aa-447c-8ab8-8263642b2116	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.12	100.01.109.00	Intereses pagados por anticipado extranjero parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
97a269c2-009b-4330-aa25-58bb8e590062	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.13	100.01.109.00	Factoraje financiero pagados por anticipado nacional	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ba1649ba-57f6-41ef-a077-417f5f0478b4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.14	100.01.109.00	Factoraje financiero pagados por anticipado extranjero	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e97a5f53-5531-40db-9789-1a0b6aca1aab	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.15	100.01.109.00	Factoraje financiero pagados por anticipado nacional parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
28465268-b47e-436f-bd2d-0ef1c7756a53	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.16	100.01.109.00	Factoraje financiero pagados por anticipado extranjero parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a70375e2-db20-4034-818c-376121e60407	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.17	100.01.109.00	Arrendamiento financiero pagados por anticipado nacional	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4ae7bb08-656d-4069-81eb-997cffa5de80	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.18	100.01.109.00	Arrendamiento financiero pagados por anticipado extranjero	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
66cb1b40-6cff-4123-ae20-7e3c455412b1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.19	100.01.109.00	Arrendamiento financiero pagados por anticipado nacional parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
82d5153d-bf6f-445d-8f1a-282123bf68f0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.20	100.01.109.00	Arrendamiento financiero pagados por anticipado extranjero parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e80b86f2-0bdf-483f-80d4-fbd0bd6651c4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.21	100.01.109.00	Pérdida por deterioro de pagos anticipados	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
225b84e7-ecdf-4034-a9e6-ff71eb1b4e04	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.22	100.01.109.00	Derechos fiduciarios	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d373ff63-98b5-436e-892c-aa13bf7784d6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.109.23	100.01.109.00	Otros pagos anticipados	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f8e79fd7-46a3-4c99-828b-6b5bba3b1096	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.110.01	100.01.110.00	Subsidio al empleo por aplicar	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c6a170b8-ae6a-4108-82fc-7f30c9ac1a44	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.111.01	100.01.111.00	Crédito al diesel por acreditar	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
599075a0-3f36-4b44-87a6-ef683f27fba1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.112.01	100.01.112.00	Otros estímulos	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
526668e3-fd22-4144-a3b3-7b1c75a41cd9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.01	100.01.113.00	IVA a favor	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f2847cb6-ce97-437e-9161-c013b6e08cc2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.02	100.01.113.00	ISR a favor	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1ac77aa5-0688-4bc5-aabf-d3fb95a23d63	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.04	100.01.113.00	IDE a favor	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
17312064-c098-4d64-8b28-ed97b762db92	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.05	100.01.113.00	IA a favor	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f86804e3-3fe5-448b-95da-2edcfbc01a12	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.06	100.01.113.00	Subsidio al empleo	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
250f6426-6dbf-4e4e-b401-ac8174eebc30	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.07	100.01.113.00	Pago de lo indebido	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c59e4e0e-f599-4670-b446-770823f8523e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.113.08	100.01.113.00	Otros impuestos a favor	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
db51d265-58f8-4230-b705-8e0d95403868	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.114.01	100.01.114.00	Pagos provisionales de ISR	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
20f22e2b-915b-438e-a62a-1f1cb0a5a303	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.115.01	100.01.115.00	Inventario	4	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fea57c64-1559-43a3-a771-4c3dd4b6f9bf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.115.02	100.01.115.00	Materia prima y materiales	4	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
23920127-c865-4dd5-93d5-f0af8915462f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.115.03	100.01.115.00	Producción en proceso	4	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9b3dc7b3-81c7-42e8-9223-7e8b6e7c1344	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.115.04	100.01.115.00	Productos terminados	4	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5c10c0db-e557-493f-8522-431fc77bf3e2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.115.05	100.01.115.00	Mercancías en tránsito	4	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e050af17-742c-4ffd-b4dc-350557a16e1d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.115.06	100.01.115.00	Mercancías en poder de terceros	4	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2942518c-81ef-4448-8ef0-125ad848d3e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.115.07	100.01.115.00	Otros	4	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5d75ce68-c687-4b95-9e65-5242d716fcf6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.116.01	100.01.116.00	Estimación de inventarios obsoletos y de lento movimiento	4	1	120	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
709cca49-c7e6-4d0d-8852-6e0b603313d8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.117.01	100.01.117.00	Obras en proceso de inmuebles	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b037f743-f6f3-4ae1-abdc-c554f8fd0e00	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.118.01	100.01.118.00	IVA acreditable pagado	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e5eab383-f40d-4f60-9471-77db19aba053	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.118.02	100.01.118.00	IVA acreditable de importación pagado	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
45db5277-f43a-414c-9400-9fed52797556	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.118.03	100.01.118.00	IEPS acreditable pagado	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
dbfb182a-c529-4b79-a031-57b09fd2fdd8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.118.04	100.01.118.00	IEPS pagado en importación	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3e6285e8-3084-4387-be5d-797eedbbe4d8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.119.01	100.01.119.00	IVA pendiente de pago	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f717ab05-ed03-4d86-adb2-ba56f2137dd0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.119.02	100.01.119.00	IVA de importación pendiente de pago	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
79d054a7-2707-412d-b945-43d16f957035	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.119.03	100.01.119.00	IEPS pendiente de pago	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bc5103e9-cdb1-45eb-8bbf-70be240090d7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.119.04	100.01.119.00	IEPS pendiente de pago en importación	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a98ce1f0-c0dc-4b43-8852-bfa67a6071bc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.120.01	100.01.120.00	Anticipo a proveedores nacional	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
64739d29-8cce-4e6e-b023-705d297984c5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.120.02	100.01.120.00	Anticipo a proveedores extranjero	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6f367cd3-18d6-4260-9873-70ab917de62a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.120.03	100.01.120.00	Anticipo a proveedores nacional parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3cd7a8ef-9aa4-4c62-8abe-cbcfcf21d64e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.120.04	100.01.120.00	Anticipo a proveedores extranjero parte relacionada	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f02d02c9-3879-422a-b0c6-a83422e30c1a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.01.121.01	100.01.121.00	Otros activos a corto plazo	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
df079fed-d8eb-4607-b7c9-5ec8b0491668	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.151.01	100.02.151.00	Terrenos	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
70a784cc-db0f-46c1-99f5-a61919f8eed8	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.152.01	100.02.152.00	Edificios	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
41c0f12b-3b89-42db-9f75-b7e57b37edf3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.153.01	100.02.153.00	Maquinaria y equipo	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cb261ad0-7200-4f9c-b9cb-476a644ed8eb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.154.01	100.02.154.00	Automóviles, autobuses, camiones de carga, tractocamiones, montacargas y remolques	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a8d17437-e20e-4353-af2c-b89effdb87f4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.155.01	100.02.155.00	Mobiliario y equipo de oficina	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
80d7bb2e-e3fa-43f7-a0c9-92f67bb4b5f0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.156.01	100.02.156.00	Equipo de cómputo	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1446623b-b92e-402f-908b-4110483d988e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.157.01	100.02.157.00	Equipo de comunicación	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
93792156-a558-4e6e-9109-c18e01e55dfb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.158.01	100.02.158.00	Activos biológicos, vegetales y semovientes	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2a84eb03-6973-4e23-b584-824307aa7e7c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.159.01	100.02.159.00	Obras en proceso de activos fijos	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f07e7cfe-f044-4750-9b6e-c2b1a874bb7f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.160.01	100.02.160.00	Otros activos fijos	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1e90f8b5-8f23-4d36-b1f4-13d97db9785c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.161.01	100.02.161.00	Ferrocarriles	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
82130559-77b6-4964-8395-5dd0661a0681	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.162.01	100.02.162.00	Embarcaciones	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5f883695-ae6c-4abc-b0f1-4537315a2cc1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.163.01	100.02.163.00	Aviones	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
375bfb96-9c6d-4012-a93d-fb1fddd17a00	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.164.01	100.02.164.00	Troqueles, moldes, matrices y herramental	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
03b773f4-c369-4abb-ae87-f9f3dbe66677	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.165.01	100.02.165.00	Equipo de comunicaciones telefónicas	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c6fb263e-eba9-4553-84e3-89ced6c5f37c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.166.01	100.02.166.00	Equipo de comunicación satelital	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bef4adaf-1a4d-4e27-af25-a9c086e8b596	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.167.01	100.02.167.00	Equipo de adaptaciones para personas con capacidades diferentes	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f5c6c320-efa1-47e4-a9ed-206030ce2d35	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.168.01	100.02.168.00	Maquinaria y equipo de generación de energía de fuentes renovables o de sistemas de cogeneración de electricidad eficiente	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
28e1de3a-3f09-4e85-bbb7-ed0fbb838c35	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.169.01	100.02.169.00	Otra maquinaria y equipo	4	1	130	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7b81ea84-ce95-49f7-8775-f6623223b77e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.170.01	100.02.170.00	Adaptaciones y mejoras	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2c07fabb-6a4c-4911-947d-7d896dfd7762	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.01	100.02.171.00	Depreciación acumulada de edificios	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
95918ce8-8da2-498f-8b64-5bdf7a03bf7a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.02	100.02.171.00	Depreciación acumulada de maquinaria y equipo	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f43e17cb-104a-401a-b19e-e29f72e36bdc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.03	100.02.171.00	Depreciación acumulada de automóviles, autobuses, camiones de carga, tractocamiones, montacargas y remolques	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
551c27ef-ccf6-4a09-be91-f423907d40bc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.04	100.02.171.00	Depreciación acumulada de mobiliario y equipo de oficina	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c0a17131-ae0b-4cf5-afb8-f3e0403bef4c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.05	100.02.171.00	Depreciación acumulada de equipo de cómputo	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c6e20616-30e8-41c7-a34a-9e3422a7e276	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.06	100.02.171.00	Depreciación acumulada de equipo de comunicación	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2df3899b-3cde-4c1f-8978-71c64daddb9c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.07	100.02.171.00	Depreciación acumulada de activos biológicos, vegetales y semovientes	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9cca32a1-0dfd-421d-bfea-8a520b07db79	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.08	100.02.171.00	Depreciación acumulada de otros activos fijos	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
abba07a0-8ba8-408f-b5a2-a54f2c401a0b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.09	100.02.171.00	Depreciación acumulada de ferrocarriles	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
59d44b9a-a181-47fb-b094-2d38839dd048	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.10	100.02.171.00	Depreciación acumulada de embarcaciones	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
548ec50f-a201-4b40-b1ed-2672a9516fb6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.11	100.02.171.00	Depreciación acumulada de aviones	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
857688bc-4136-4ac8-97f4-cf6d574efe72	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.12	100.02.171.00	Depreciación acumulada de troqueles, moldes, matrices y herramental	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ff6f86fe-159d-4b28-a999-1e3495752690	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.13	100.02.171.00	Depreciación acumulada de equipo de comunicaciones telefónicas	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f0523fd4-5270-446c-9fb1-33bcbbcfdf33	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.14	100.02.171.00	Depreciación acumulada de equipo de comunicación satelital	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7ecccbb4-e7eb-4d09-b63e-7d7e634802b0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.15	100.02.171.00	Depreciación acumulada de equipo de adaptaciones para personas con capacidades diferentes	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
12738002-3663-47b1-83fd-99d0d9e84b62	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.16	100.02.171.00	Depreciación acumulada de maquinaria y equipo de generación de energía de fuentes renovables o de sistemas de cogeneración de electricidad eficiente	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
32aa0ec0-9897-4258-8e82-b5080309eb62	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.17	100.02.171.00	Depreciación acumulada de adaptaciones y mejoras	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1a8dfa49-9f4b-4cc6-b3d4-a13c79974fd6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.171.18	100.02.171.00	Depreciación acumulada de otra maquinaria y equipo	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
962b284e-ce49-419d-80fc-2b4228b8b766	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.01	100.02.172.00	Pérdida por deterioro acumulado de edificios	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0e8b897d-dd06-4a43-8320-86b8b06fe498	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.02	100.02.172.00	Pérdida por deterioro acumulado de maquinaria y equipo	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c4dfbd68-5728-4313-bee4-aebf57b84ee4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.03	100.02.172.00	Pérdida por deterioro acumulado de automóviles, autobuses, camiones de carga, tractocamiones, montacargas y remolques	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1f132d84-2fa3-45da-ab22-db04f3b54ae5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.04	100.02.172.00	Pérdida por deterioro acumulado de mobiliario y equipo de oficina	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a91d7e1c-9c42-482e-abc9-2ce4a2d5eea9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.05	100.02.172.00	Pérdida por deterioro acumulado de equipo de cómputo	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
55245cf8-ccaa-48a8-ac17-f86f4bfddb22	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.06	100.02.172.00	Pérdida por deterioro acumulado de equipo de comunicación	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6f9eb1ed-68b8-4115-982a-130a7bd8785d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.07	100.02.172.00	Pérdida por deterioro acumulado de activos biológicos, vegetales y semovientes	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7fae5e01-5359-47a7-8524-4f72d1d89718	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.08	100.02.172.00	Pérdida por deterioro acumulado de otros activos fijos	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ae045f52-050f-490e-9fbd-325896dc821b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.09	100.02.172.00	Pérdida por deterioro acumulado de ferrocarriles	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
aacc485e-01a4-4674-8229-b6b1e11b4e0b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.10	100.02.172.00	Pérdida por deterioro acumulado de embarcaciones	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
efb25d69-3ae4-4f70-8785-a18f07d1b0b6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.11	100.02.172.00	Pérdida por deterioro acumulado de aviones	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3561a29d-a016-4132-89f9-a6ee86aa8cf3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.12	100.02.172.00	Pérdida por deterioro acumulado de troqueles, moldes, matrices y herramental	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c81487ab-ea37-4fee-8e99-edb7d709abe4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.13	100.02.172.00	Pérdida por deterioro acumulado de equipo de comunicaciones telefónicas	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b52a7d96-1610-41cc-8dc6-e9e2939a1b33	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.14	100.02.172.00	Pérdida por deterioro acumulado de equipo de comunicación satelital	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
37820dca-fb6d-492e-ba42-125fb3f7fb98	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.15	100.02.172.00	Pérdida por deterioro acumulado de equipo de adaptaciones para personas con capacidades diferentes	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
db3962cd-9f96-40d2-afe0-057e47e1d67d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.16	100.02.172.00	Pérdida por deterioro acumulado de maquinaria y equipo de generación de energía de fuentes renovables o de sistemas de cogeneración de electricidad eficiente	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9cfbeac0-0600-4565-ad3f-5c1576383a7c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.17	100.02.172.00	Pérdida por deterioro acumulado de adaptaciones y mejoras	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e06e5916-5a64-4343-909d-421da41c3e48	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.172.18	100.02.172.00	Pérdida por deterioro acumulado de otra maquinaria y equipo	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
340c1f6f-f7ae-4aec-bad9-0a1d3abf8d6c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.173.01	100.02.173.00	Gastos diferidos	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5b78127e-d6c8-4e5d-9263-608625505909	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.174.01	100.02.174.00	Gastos pre operativos	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0fea79c3-091d-4cd8-977e-b5c7c39a1daa	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.175.01	100.02.175.00	Regalías, asistencia técnica y otros gastos diferidos	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1faa840b-ca1a-4d85-ae6c-641a4b945dfc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.176.01	100.02.176.00	Activos intangibles	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
77145ddc-0d49-4eb9-a1b7-498c23d93a15	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.177.01	100.02.177.00	Gastos de organización	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9c912a55-ea0e-4901-8b1e-9bbfab47ba83	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.178.01	100.02.178.00	Investigación y desarrollo de mercado	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7df51465-36d6-4eae-b4f3-5db5b57e647b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.179.01	100.02.179.00	Marcas y patentes	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
733247f7-dc04-4bf8-9c8c-7c2fba2f48f7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.180.01	100.02.180.00	Crédito mercantil	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
65f382d4-e7a4-47ba-a256-ed8a4d41e66f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.181.01	100.02.181.00	Gastos de instalación	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5ab6964c-a58a-4f53-9438-44a1729eba2a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.182.01	100.02.182.00	Otros activos diferidos	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
63064aa2-e111-4264-bb9e-3f5e11d22b3e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.01	100.02.183.00	Amortización acumulada de gastos diferidos	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
31bb42a1-91dd-41ca-a403-ef2df74228b9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.02	100.02.183.00	Amortización acumulada de gastos pre operativos	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
39261fe9-4654-4b59-9ad8-81bf115e4964	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.03	100.02.183.00	Amortización acumulada de regalías, asistencia técnica y otros gastos diferidos	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0bb8a8aa-1945-4719-a53f-3450aa346409	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.04	100.02.183.00	Amortización acumulada de activos intangibles	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
65dad2a1-d575-4981-8cc7-934f59133ef6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.05	100.02.183.00	Amortización acumulada de gastos de organización	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ebe6856a-652b-440a-9619-274b79af1412	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.06	100.02.183.00	Amortización acumulada de investigación y desarrollo de mercado	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7d0653e1-e5c1-4ba0-a93f-ceded54e15bd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.07	100.02.183.00	Amortización acumulada de marcas y patentes	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
79a02818-f2cd-427d-a583-85ea5d7e0714	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.08	100.02.183.00	Amortización acumulada de crédito mercantil	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
55deb059-dbdc-4b74-83bb-d0b25749f8f6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.09	100.02.183.00	Amortización acumulada de gastos de instalación	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
03da9068-4879-4cb6-a21c-4c93dd123418	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.183.10	100.02.183.00	Amortización acumulada de otros activos diferidos	4	1	131	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b04d2905-5d93-4cfa-89f6-488877a69fb2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.184.01	100.02.184.00	Depósitos de fianzas	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8a0f623d-9042-4958-957e-fdb97ab41c1c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.184.02	100.02.184.00	Depósitos de arrendamiento de bienes inmuebles	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
acde26da-9ded-4179-b5a6-1ba337686a26	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.184.03	100.02.184.00	Otros depósitos en garantía	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a934a1e1-86ee-4a64-9e60-53b35ef83ddf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.185.01	100.02.185.00	Impuestos diferidos ISR	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
24446a03-371e-4e70-88b9-3ad5f73686de	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.01	100.02.186.00	Cuentas y documentos por cobrar a largo plazo nacional	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3727fd17-37d8-41ac-b22a-972daa032f48	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.02	100.02.186.00	Cuentas y documentos por cobrar a largo plazo extranjero	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4f2a9b28-39b5-4005-8f2d-6a56ca3a13a6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.03	100.02.186.00	Cuentas y documentos por cobrar a largo plazo nacional parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3ca0735d-8a99-4331-8191-324b0f06e9a9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.04	100.02.186.00	Cuentas y documentos por cobrar a largo plazo extranjero parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
41a11373-5fac-43cd-b435-f7d682164473	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.05	100.02.186.00	Intereses por cobrar a largo plazo nacional	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
15d1e224-d8de-491a-a7cc-b85db21d92c6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.06	100.02.186.00	Intereses por cobrar a largo plazo extranjero	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
308fe2be-bdcd-4387-8e4f-2535d8047259	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.07	100.02.186.00	Intereses por cobrar a largo plazo nacional parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
26344633-bb0c-4286-8679-dfbfdc0bfc1f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.08	100.02.186.00	Intereses por cobrar a largo plazo extranjero parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6c5421e2-434d-4dc1-b111-2274d1aa1bda	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.09	100.02.186.00	Otras cuentas y documentos por cobrar a largo plazo	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
80798bd9-69c9-43bb-a3a2-c2e63f2953ae	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.186.10	100.02.186.00	Otras cuentas y documentos por cobrar a largo plazo parte relacionada	4	1	110	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
67138183-7837-43dc-8e6f-810730d8b39f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.187.01	100.02.187.00	Participación de los trabajadores en las utilidades diferidas	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d7d49918-ddc8-4471-ae8d-dfc7f5209faa	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.188.01	100.02.188.00	Inversiones a largo plazo en subsidiarias	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
88670dcf-6c23-4249-b030-374c963f1376	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.188.02	100.02.188.00	Inversiones a largo plazo en asociadas	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
19cdc891-84cc-42f9-9724-c522587960bb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.188.03	100.02.188.00	Otras inversiones permanentes en acciones	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
797e300a-8c78-4d8a-8a11-b01cc4d2bb01	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.189.01	100.02.189.00	Estimación por deterioro de inversiones permanentes en acciones	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
441952c6-2cb8-427f-83b9-523f6dc50672	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.190.01	100.02.190.00	Otros instrumentos financieros	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
32f7b6ee-6514-4f5e-acb7-4ed09ba64a94	2dcdfa08-ce3a-4c75-8d76-6566257437d3	100.02.191.01	100.02.191.00	Otros activos a largo plazo	4	1	199	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
994fa8d5-8cf0-4168-acdd-a17cd9ae948b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.201.01	200.01.201.00	Proveedores nacionales	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a1c81195-a81c-4486-8036-8f990a3b841e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.201.02	200.01.201.00	Proveedores extranjeros	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a5c93367-0e76-464e-9453-91bdc6ba7f86	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.201.03	200.01.201.00	Proveedores nacionales parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e5c56152-145c-47dc-b287-37e9a5f9f977	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.201.04	200.01.201.00	Proveedores extranjeros parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b7bbff97-26ff-4d8d-8895-837e9005875c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.01	200.01.202.00	Documentos por pagar bancario y financiero nacional	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
612453bd-d4f0-4867-a9c0-b23e4cfc8aa0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.02	200.01.202.00	Documentos por pagar bancario y financiero extranjero	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2775149e-6561-4e91-a3e2-3edc5da426eb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.03	200.01.202.00	Documentos y cuentas por pagar a corto plazo nacional	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
25c19466-370a-4c2c-a165-cc72173a4147	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.04	200.01.202.00	Documentos y cuentas por pagar a corto plazo extranjero	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
eeec7e6c-13ae-43bc-9e96-08a41830f0d4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.05	200.01.202.00	Documentos y cuentas por pagar a corto plazo nacional parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
340a7fdc-a906-4957-8500-8edb0dac70bf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.06	200.01.202.00	Documentos y cuentas por pagar a corto plazo extranjero parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
36b21474-f215-4cc5-a585-186279060fc2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.07	200.01.202.00	Intereses por pagar a corto plazo nacional	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ffbb3861-f344-465c-8f40-197fc4bb02bb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.08	200.01.202.00	Intereses por pagar a corto plazo extranjero	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bcf90629-8832-415a-b441-1c18d5e0c6d4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.09	200.01.202.00	Intereses por pagar a corto plazo nacional parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2caa82eb-8532-4756-8007-98e11a41d689	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.10	200.01.202.00	Intereses por pagar a corto plazo extranjero parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b437aafe-e733-49ae-9ee2-92982638921c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.11	200.01.202.00	Dividendo por pagar nacional	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b833d44f-8d81-412b-b693-9f7b83fe36f5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.202.12	200.01.202.00	Dividendo por pagar extranjero	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cfab0aef-8baf-43d1-b0ae-d620f4307099	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.01	200.01.203.00	Rentas cobradas por anticipado a corto plazo nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b1092284-5be3-4008-a40d-23c3431fe00f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.02	200.01.203.00	Rentas cobradas por anticipado a corto plazo extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9d7a631b-1acb-40fe-92f0-1e52b4e726ab	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.03	200.01.203.00	Rentas cobradas por anticipado a corto plazo nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7e4d0eb1-9f30-4143-9ba7-bfd83210e1b2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.04	200.01.203.00	Rentas cobradas por anticipado a corto plazo extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4c4cfc88-3203-4bc5-8e59-bc06f650451d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.05	200.01.203.00	Intereses cobrados por anticipado a corto plazo nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
955ca6b5-d3a8-4909-979c-e85ffe61ac18	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.06	200.01.203.00	Intereses cobrados por anticipado a corto plazo extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
85d48fd7-c5c1-4302-969b-bfd136c20008	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.07	200.01.203.00	Intereses cobrados por anticipado a corto plazo nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cf59368c-fc6d-4bbf-9574-873d946f4e14	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.08	200.01.203.00	Intereses cobrados por anticipado a corto plazo extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a2342280-2f9a-402c-8880-2a15a330f8bf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.09	200.01.203.00	Factoraje financiero cobrados por anticipado a corto plazo nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a75f7de5-2d0a-421e-9e1e-70a4dc3b37ba	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.10	200.01.203.00	Factoraje financiero cobrados por anticipado a corto plazo extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7b4b13d5-f89d-4778-807c-dc1e1fcf6480	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.11	200.01.203.00	Factoraje financiero cobrados por anticipado a corto plazo nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2674a6ad-a956-4c59-b3fa-6dbdf1db0731	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.12	200.01.203.00	Factoraje financiero cobrados por anticipado a corto plazo extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9380ea6d-3185-4fd7-9f50-562410e51c60	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.13	200.01.203.00	Arrendamiento financiero cobrados por anticipado a corto plazo nacional	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
328d9242-c8f5-46b4-a050-90fdf029cb0b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.14	200.01.203.00	Arrendamiento financiero cobrados por anticipado a corto plazo extranjero	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f6a65940-5f3b-4f52-83f1-829aadf19b44	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.15	200.01.203.00	Arrendamiento financiero cobrados por anticipado a corto plazo nacional parte relacionada	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
80237e8d-afe8-4f43-9eee-057771fcc07e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.16	200.01.203.00	Arrendamiento financiero cobrados por anticipado a corto plazo extranjero parte relacionada	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9f3321e9-9b67-4093-ad54-13c91d0c815c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.17	200.01.203.00	Derechos fiduciarios	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
25166aea-dd19-49b7-a72b-4c90dd174ddc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.203.18	200.01.203.00	Otros cobros anticipados	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f8fca188-ef76-4aad-8c01-772ec34409b1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.204.01	200.01.204.00	Instrumentos financieros a corto plazo	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1d6a03b6-5e64-4410-96ab-753def4bc7ff	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.205.01	200.01.205.00	Socios, accionistas o representante legal	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e77643a1-a9ec-4982-9b59-3bb34d3ee76d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.205.02	200.01.205.00	Acreedores diversos a corto plazo nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5911cf71-9e58-4e2e-9e6f-daa47066953f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.205.03	200.01.205.00	Acreedores diversos a corto plazo extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
05267eab-01f2-44fb-bf72-5dec08750d7e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.205.04	200.01.205.00	Acreedores diversos a corto plazo nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3895775a-7b03-4701-af98-f295d586dbfa	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.205.05	200.01.205.00	Acreedores diversos a corto plazo extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d01c87ad-3018-4a8c-87af-f55004030c6f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.205.06	200.01.205.00	Otros acreedores diversos a corto plazo	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
401513d8-7ae7-473b-941e-d55cefac501e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.206.01	200.01.206.00	Anticipo de cliente nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a56eac68-6a18-43af-bfac-102564f350cc	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.206.02	200.01.206.00	Anticipo de cliente extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2d902e06-46a3-43e2-a3a0-fcea570da497	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.206.03	200.01.206.00	Anticipo de cliente nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c0933df9-9446-426c-b5b4-5d57da16c7ac	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.206.04	200.01.206.00	Anticipo de cliente extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7d9c300d-f6dc-4ebb-96b6-ca2a954eff2c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.206.05	200.01.206.00	Otros anticipos de clientes	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4a52ee24-0540-44ba-9b29-3c8ca8e23417	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.207.01	200.01.207.00	IVA trasladado	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f93610cf-be52-4746-b88c-c45583a6ab5e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.207.02	200.01.207.00	IEPS trasladado	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
efe4faa3-c985-4b4c-aeab-2cd48e88be8f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.208.01	200.01.208.00	IVA trasladado cobrado	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c4908393-5eba-47a3-9eea-eaa727c4554a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.208.02	200.01.208.00	IEPS trasladado cobrado	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ebb389a2-da69-4a18-b70f-fbfe5b8d81a0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.209.01	200.01.209.00	IVA trasladado no cobrado	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cff0ef4f-4e88-44cb-bed8-1cd513afe802	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.209.02	200.01.209.00	IEPS trasladado no cobrado	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
096c431c-e7d7-4256-b9d7-9ee35fa5add0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.210.01	200.01.210.00	Provisión de sueldos y salarios por pagar	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f45c2662-87b5-4708-89e1-6281f94c4bc3	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.210.02	200.01.210.00	Provisión de vacaciones por pagar	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0596da31-c734-401b-ae8a-83c60199a554	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.210.03	200.01.210.00	Provisión de aguinaldo por pagar	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a70834df-db51-4504-b128-baa497c51362	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.210.04	200.01.210.00	Provisión de fondo de ahorro por pagar	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ac6e1273-cb9d-4cc2-aa6a-2f8ce5cfb577	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.210.05	200.01.210.00	Provisión de asimilados a salarios por pagar	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f9261379-579b-40e8-b840-24614142c248	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.210.06	200.01.210.00	Provisión de anticipos o remanentes por distribuir	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5af12324-e5ad-4a5b-9d40-30393a57f8ab	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.210.07	200.01.210.00	Provisión de otros sueldos y salarios por pagar	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
49e13822-92b4-431e-a4e4-2e392473ccee	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.211.01	200.01.211.00	Provisión de IMSS patronal por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f03aa449-e1c0-446f-b4a6-6010b0af099f	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.211.02	200.01.211.00	Provisión de SAR por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
082a9eb9-126d-482e-bf8f-de9f4d334793	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.211.03	200.01.211.00	Provisión de infonavit por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3681cc9e-acaf-4989-b31b-f1a5e032c8ff	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.212.01	200.01.212.00	Provisión de impuesto estatal sobre nómina por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e52ab475-94d8-41a0-953a-61a1baa5ac43	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.213.01	200.01.213.00	IVA por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1df42c06-318b-4f25-9998-6c4774bc3271	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.213.02	200.01.213.00	IEPS por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
259a0b1e-5224-4eb8-8a19-c6fa1b777b19	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.213.03	200.01.213.00	ISR por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1c22734c-5ac0-4bff-a550-82f86a0ebbd2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.213.04	200.01.213.00	Impuesto estatal sobre nómina por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0ffa26f7-3d9d-474f-919a-7b6d2bd130e6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.213.05	200.01.213.00	Impuesto estatal y municipal por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1e31b5db-0b76-4530-8de7-5b572f7540cd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.213.06	200.01.213.00	Derechos por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
5bbb8c79-d844-4faa-bff4-dff3ff66a7c7	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.213.07	200.01.213.00	Otros impuestos por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d5d7ed95-799c-43f0-957e-42494879723c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.214.01	200.01.214.00	Dividendos por pagar	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
3a1c28b3-ae43-417a-9b3f-4966a7f6a714	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.215.01	200.01.215.00	PTU por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
906b26a0-02dc-4992-9d08-2d6e417afd6c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.215.02	200.01.215.00	PTU por pagar de ejercicios anteriores	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
fa14dfa7-fc16-4816-abe4-9e1caaccd874	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.215.03	200.01.215.00	Provisión de PTU por pagar	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2818f09f-3fba-42fe-a99d-edb252854c53	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.01	200.01.216.00	Impuestos retenidos de ISR por sueldos y salarios	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
df7c90fd-1d07-4680-9b11-9ef5b8f1ebce	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.02	200.01.216.00	Impuestos retenidos de ISR por asimilados a salarios	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c1d66bc3-3494-4993-9512-27982fe7ede2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.03	200.01.216.00	Impuestos retenidos de ISR por arrendamiento	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7384f3a3-a1e1-42a0-8a0a-b812c42994dd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.04	200.01.216.00	Impuestos retenidos de ISR por servicios profesionales	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ba94b495-377b-4d2a-ada6-7276ee3d7b06	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.05	200.01.216.00	Impuestos retenidos de ISR por dividendos	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
92dde5b2-865a-4b35-bcf3-fb4c0eb02c21	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.06	200.01.216.00	Impuestos retenidos de ISR por intereses	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ab74d3f2-ea66-4198-8a22-b5540494176e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.07	200.01.216.00	Impuestos retenidos de ISR por pagos al extranjero	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
da3ac620-ebd2-4bb4-817f-cc479fec9577	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.08	200.01.216.00	Impuestos retenidos de ISR por venta de acciones	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
45e24504-5028-4bb9-ad67-d10f457df785	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.09	200.01.216.00	Impuestos retenidos de ISR por venta de partes sociales	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
48ec235a-a436-4237-a186-835b16c7038d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.10	200.01.216.00	Impuestos retenidos de IVA	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0fccf591-f65d-487a-bd38-848af300efb9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.11	200.01.216.00	Retenciones de IMSS a los trabajadores	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
64209246-f2bd-4fe8-84cb-8d8d94732840	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.216.12	200.01.216.00	Otras impuestos retenidos	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d0ef6c36-72ad-47bd-8267-5278fc3296f9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.217.01	200.01.217.00	Pagos realizados por cuenta de terceros	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
008953c5-8c03-4e4c-acc9-5a09446fd181	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.01.218.01	200.01.000.00	Otros pasivos a corto plazo	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
51753653-e92d-46d5-9434-8f4486461c26	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.251.01	200.02.251.00	Socios, accionistas o representante legal	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2525a44f-72d9-444a-9e7d-9f7e902fa073	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.251.02	200.02.251.00	Acreedores diversos a largo plazo nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
d3658f79-9e83-4cb5-b11f-358142340ce5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.251.03	200.02.251.00	Acreedores diversos a largo plazo extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
23b29a94-857b-4f17-8053-160e39fc4110	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.251.04	200.02.251.00	Acreedores diversos a largo plazo nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1d14244e-4dcd-4888-a03a-a452060bed2b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.251.05	200.02.251.00	Acreedores diversos a largo plazo extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e67e3a01-d5ca-4be0-9869-e519e8e9f7f5	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.251.06	200.02.251.00	Otros acreedores diversos a largo plazo	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
875769da-6828-4501-a3ab-25652752b5ae	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.01	200.02.252.00	Documentos bancarios y financieros por pagar a largo plazo nacional	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c8982cc7-48e9-4456-b18c-cd1a5c06c3f1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.02	200.02.252.00	Documentos bancarios y financieros por pagar a largo plazo extranjero	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2939859f-0a62-4eb3-8b1e-f3c559eb59d1	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.03	200.02.252.00	Documentos y cuentas por pagar a largo plazo nacional	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
50f3443a-5410-4257-9d32-246883d5f381	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.04	200.02.252.00	Documentos y cuentas por pagar a largo plazo extranjero	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e092ce23-ab15-475c-b45a-3e5b0bfb1ed0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.05	200.02.252.00	Documentos y cuentas por pagar a largo plazo nacional parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6fe37971-404c-4f2b-a944-057f553343be	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.06	200.02.252.00	Documentos y cuentas por pagar a largo plazo extranjero parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9ea06851-bd58-4bba-9034-cef173c6eaf0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.07	200.02.252.00	Hipotecas por pagar a largo plazo nacional	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ab70a8dc-edfe-4add-bd84-f1946ab1e0d4	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.08	200.02.252.00	Hipotecas por pagar a largo plazo extranjero	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f8035054-ca21-470f-a7a0-2a5b10788a57	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.09	200.02.252.00	Hipotecas por pagar a largo plazo nacional parte relacionada	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4950f2b4-4da2-409e-bda7-f59b447a38fd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.10	200.02.252.00	Hipotecas por pagar a largo plazo extranjero parte relacionada	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
b555045b-87bd-4099-bb0e-88cb376bce3c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.11	200.02.252.00	Intereses por pagar a largo plazo nacional	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
6d07d80b-f763-49d9-91b4-7946874701d6	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.12	200.02.252.00	Intereses por pagar a largo plazo extranjero	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
715256a3-c1f3-434d-a2c3-19ce29162b39	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.13	200.02.252.00	Intereses por pagar a largo plazo nacional parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
79ef32b7-1723-4bd5-8008-e49085c1fcdd	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.14	200.02.252.00	Intereses por pagar a largo plazo extranjero parte relacionada	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
bdd0e3f1-4745-40e8-9bbc-2f84b280b7c9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.15	200.02.252.00	Dividendos por pagar nacionales	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
51070d2f-e3ec-4237-9aba-1bc55bd647b2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.16	200.02.252.00	Dividendos por pagar extranjeros	4	2	200	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
1f3bad2a-b489-4fae-8222-f3316ea124b9	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.252.17	200.02.252.00	Otras cuentas y documentos por pagar a largo plazo	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
21c91d2f-b1bf-4838-83a6-cef8616525c0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.01	200.02.253.00	Rentas cobradas por anticipado a largo plazo nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
ebec89ca-ce15-4412-b546-bb9c3e79dc44	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.02	200.02.253.00	Rentas cobradas por anticipado a largo plazo extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
0295b39b-ab5e-4b38-9c47-3bdfee67684b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.03	200.02.253.00	Rentas cobradas por anticipado a largo plazo nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
c869d8df-426a-4815-8c86-890d1ce37d74	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.04	200.02.253.00	Rentas cobradas por anticipado a largo plazo extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e97cddc1-2266-4fe9-a0db-8388743edf62	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.05	200.02.253.00	Intereses cobrados por anticipado a largo plazo nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e0632652-7419-4345-9473-c2f131828a6c	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.06	200.02.253.00	Intereses cobrados por anticipado a largo plazo extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
7102dd18-aef0-49a4-a682-03115099c78d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.07	200.02.253.00	Intereses cobrados por anticipado a largo plazo nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a3718a7d-5b93-4ab8-9cbb-989831f479f2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.08	200.02.253.00	Intereses cobrados por anticipado a largo plazo extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
45fc1e2e-08f1-4855-95fa-861fb720539e	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.09	200.02.253.00	Factoraje financiero cobrados por anticipado a largo plazo nacional	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
afbb0a31-086b-4df5-9219-5c93b0b142ad	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.10	200.02.253.00	Factoraje financiero cobrados por anticipado a largo plazo extranjero	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
e096dd36-451c-4b89-8956-e52557551323	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.11	200.02.253.00	Factoraje financiero cobrados por anticipado a largo plazo nacional parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
75c550a8-507d-4b74-be83-07a884dafcd0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.12	200.02.253.00	Factoraje financiero cobrados por anticipado a largo plazo extranjero parte relacionada	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4298c8fd-a8d8-47be-856e-ef9447da814a	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.13	200.02.253.00	Arrendamiento financiero cobrados por anticipado a largo plazo nacional	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
a82f64ca-2216-4452-8f3b-4c20787349e0	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.14	200.02.253.00	Arrendamiento financiero cobrados por anticipado a largo plazo extranjero	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
637de2c8-9bb2-4ef5-b538-8847d7689fbf	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.15	200.02.253.00	Arrendamiento financiero cobrados por anticipado a largo plazo nacional parte relacionada	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
72166303-463e-4ca8-810c-988f59a48775	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.16	200.02.253.00	Arrendamiento financiero cobrados por anticipado a largo plazo extranjero parte relacionada	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
38e13396-1b38-4202-a53a-5aa0ab9ab049	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.17	200.02.253.00	Derechos fiduciarios	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
39e4c03e-184e-4ed1-a43b-29f1be4b4d04	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.253.18	200.02.253.00	Otros cobros anticipados	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
de002593-984c-4ff1-bcf0-128deba3597b	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.254.01	200.02.254.00	Instrumentos financieros a largo plazo	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
72ef888e-a8a1-4734-9ee3-0afff48ee0cb	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.255.01	200.02.255.00	Pasivos por beneficios a los empleados a largo plazo	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
8e17fd33-6673-49cb-baeb-8a8ba27fb675	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.256.01	200.02.256.00	Otros pasivos a largo plazo	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
4d03f2ee-e88d-4400-9060-fea0414a3265	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.257.01	200.02.257.00	Participación de los trabajadores en las utilidades diferida	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
2df4bf83-0a10-4f88-8321-168b26003dd2	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.258.01	200.02.258.00	Obligaciones contraídas de fideicomisos	4	2	220	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
9bad8015-c8be-42d1-9aff-686979cd2c00	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.259.01	200.02.259.00	ISR diferido	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
cc3d7d1f-86d3-41d6-9898-9427dd9cf687	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.259.02	200.02.259.00	ISR por dividendo diferido	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
f55ff5ea-52c6-4dd8-8541-f90216365a17	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.259.03	200.02.259.00	Otros impuestos diferidos	4	2	210	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
eddf70b2-fc11-455d-bc8a-f2df4d7b047d	2dcdfa08-ce3a-4c75-8d76-6566257437d3	200.02.260.01	200.02.260.00	Pasivos diferidos	4	2	299	f	2026-02-05 15:51:48.767246-06	2026-02-05 15:51:48.767246-06	\N
\.


--
-- TOC entry 4141 (class 0 OID 16506)
-- Dependencies: 247
-- Data for Name: commodity; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.commodity (id, mnemonic, namespace, full_name, fraction, is_active, created_at, updated_at, revision, deleted_at) FROM stdin;
7b87c7f1-dd91-4b50-b8a0-c26f0e5e049a	AED	CURRENCY	UAE Dirham	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
e8a37273-fac1-4c05-b45b-e40aec2cf114	AFN	CURRENCY	Afghani	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f4824f28-9bfb-48d4-a2e8-a9e78ec5755f	ALL	CURRENCY	Lek	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
066a8aaf-c231-4e0c-bdad-ce98c06b73a2	AMD	CURRENCY	Armenian Dram	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
4fa3993c-395d-4094-adba-fc995a789830	AOA	CURRENCY	Kwanza	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
bcaf0a16-1f3a-4686-8af4-46438bcf9587	ARS	CURRENCY	Argentine Peso	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
e12c8922-7a2d-4226-b1d7-37b0522da9b4	AUD	CURRENCY	Australian Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
5a1afda4-7440-4a77-8fef-d8d1e2a23639	AWG	CURRENCY	Aruban Florin	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
6d618650-81b2-4dfd-bff6-b1d12c791f40	AZN	CURRENCY	Azerbaijan Manat	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
9b040c12-fc46-4d18-8829-204536f0e9b3	BAM	CURRENCY	Convertible Mark	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
63297800-0567-4dc4-9b4b-a3b9f5bdb935	BBD	CURRENCY	Barbados Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
16fc902a-d249-4c2b-bc39-8357f60df346	BDT	CURRENCY	Taka	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
3e53c50e-32d5-40ff-8d34-060cefede4bb	BHD	CURRENCY	Bahraini Dinar	1000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
51f27eee-7ccc-4a6d-bd95-30ac81faf541	BIF	CURRENCY	Burundi Franc	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
eb5d9e0f-ab86-449f-9795-b99d74c8adde	BMD	CURRENCY	Bermudian Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
3f46b5ec-fd62-4955-9310-ecfc711e86ae	BND	CURRENCY	Brunei Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
578e036b-a397-48ab-b0f8-9e7d636b5a76	BOB	CURRENCY	Boliviano	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b4fb8c48-e253-4b65-ad7f-4677a3baac75	BOV	CURRENCY	Mvdol	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f20045c3-e6ba-4b38-ae53-5d5f6d100afa	BRL	CURRENCY	Brazilian Real	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c8b3fec0-7f44-425e-a046-d6849b09493a	BSD	CURRENCY	Bahamian Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
e87d1837-455c-46ef-9ff9-025c8ee7697b	BTN	CURRENCY	Ngultrum	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
53b4b09b-60b0-4498-a8c0-1595c4af478b	BWP	CURRENCY	Pula	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c848012d-64d8-48b0-b663-eab79fb365a2	BYN	CURRENCY	Belarusian Ruble	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
351e6a5e-0661-4a46-971f-84d6ee4eb2e3	BZD	CURRENCY	Belize Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
7f1ec00e-c9d3-4f7f-a957-7208e2a871ab	CAD	CURRENCY	Canadian Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
7e2ee745-fa10-4998-a4d6-9ab15c6aac01	CDF	CURRENCY	Congolese Franc	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
4860b590-7a8d-43dc-9f69-fc1a2f439424	CHE	CURRENCY	WIR Euro	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
247cf7ae-dece-4f7e-93d4-cae05b702c6a	CHF	CURRENCY	Swiss Franc	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
ea6b22bf-d746-4e76-b36f-f2b8395ecbb2	CHW	CURRENCY	WIR Franc	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
6bdbbe29-028e-4ea0-b701-9a9c7df5e168	CLF	CURRENCY	Unidad de Fomento	10000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b3f66343-94f0-44af-9fbb-5ef75a06d002	CLP	CURRENCY	Chilean Peso	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
3a41cb91-5c75-4adc-8587-d7af5e8aadcc	CNY	CURRENCY	Yuan Renminbi	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
66db566b-0cee-42a8-b8d3-ff25b9664dfd	COP	CURRENCY	Colombian Peso	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f69c4c6d-8c88-48e7-90cf-a486d73d83a3	COU	CURRENCY	Unidad de Valor Real	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
af66531a-4235-4f47-a7f3-6636f3e68ce3	CRC	CURRENCY	Costa Rican Colon	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
38065c9e-09b1-42b3-86b3-7f683c61a725	CUP	CURRENCY	Cuban Peso	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
344d349f-da59-4a05-9e26-5e89d9afc380	CVE	CURRENCY	Cabo Verde Escudo	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8e1c1f41-a0e3-42e1-8143-ab823b71f28f	CZK	CURRENCY	Czech Koruna	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
d7142099-fef8-45d7-83d2-47881d4b151e	DJF	CURRENCY	Djibouti Franc	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
ddbd1488-9b02-45d9-9820-42d9f2f0470f	DKK	CURRENCY	Danish Krone	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
06821c3a-c955-42b4-9b44-2440f9d8b31d	DOP	CURRENCY	Dominican Peso	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
1570cabb-869c-4446-9f32-3e44f537cb03	DZD	CURRENCY	Algerian Dinar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
636c5667-a343-4a23-bcde-49754d8e8005	EGP	CURRENCY	Egyptian Pound	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
ad09325a-26bf-4620-a5f6-7ec970ad4f96	ERN	CURRENCY	Nakfa	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2b8cb3ca-65d3-4779-bf06-01283035444e	ETB	CURRENCY	Ethiopian Birr	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
746f4a87-15f4-4f6e-b6df-ac8900d130b2	EUR	CURRENCY	Euro	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
4ee91200-14a0-406c-a6f2-d3d2357b605f	FJD	CURRENCY	Fiji Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
70df2265-6c7d-4d58-bdd0-510575110f3f	FKP	CURRENCY	Falkland Islands Pound	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
642eac14-6fed-4970-8546-b96d4f0bf7de	GBP	CURRENCY	Pound Sterling	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
410a3eb6-0f29-41bf-b5aa-b06daed2d5e5	GEL	CURRENCY	Lari	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
bf5e3d63-b89f-45dd-b2c1-fc4b1206578a	GHS	CURRENCY	Ghana Cedi	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
317e7303-9e6a-4517-a3ce-52593f3de149	GIP	CURRENCY	Gibraltar Pound	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
eb739952-6f62-48ba-b4b0-50415563203d	GMD	CURRENCY	Dalasi	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8a10b909-011c-4f96-b018-331fcb1b501d	GNF	CURRENCY	Guinean Franc	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
9f3aff58-ce87-478b-9888-38239ec3c672	GTQ	CURRENCY	Quetzal	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
5a1e7b1d-3e90-487f-9c82-b78e849aab7b	GYD	CURRENCY	Guyana Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
ce586efc-a9bf-43ec-9e8f-306759353a97	HKD	CURRENCY	Hong Kong Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
7e7139df-15d0-4ddb-b08a-7cdd0d3c5080	HNL	CURRENCY	Lempira	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2bc95003-81a7-44db-93fd-a15a39099546	HTG	CURRENCY	Gourde	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
182b8edd-9f42-4d19-b6f0-f178d91652b3	HUF	CURRENCY	Forint	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b45b194d-ef8c-45d0-86a8-cf1df534d023	IDR	CURRENCY	Rupiah	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2b8d9ebf-9f9e-45a2-8b92-3acf588216f6	ILS	CURRENCY	New Israeli Sheqel	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8da06d32-ba61-4ccb-b87d-28be4c9a26e9	INR	CURRENCY	Indian Rupee	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8ad81154-3b8a-407f-8dac-ee07d02563ee	IQD	CURRENCY	Iraqi Dinar	1000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
e3a85a36-b6e3-4f03-bba3-155152c76392	IRR	CURRENCY	Iranian Rial	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
a33061f9-938f-44d1-937d-b491254c0324	ISK	CURRENCY	Iceland Krona	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f0982d1c-5739-4e54-be36-3082b19481c5	JMD	CURRENCY	Jamaican Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f775ae66-10f1-4f2a-823a-8940d85b6553	JOD	CURRENCY	Jordanian Dinar	1000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
4f420790-427c-49e8-8349-fd46e95c2077	JPY	CURRENCY	Yen	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2d56a72d-872e-4c89-a874-5351fa6d40b3	KES	CURRENCY	Kenyan Shilling	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
08b2997d-db9c-4b61-9b8c-a1b76e1aff1d	KGS	CURRENCY	Som	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2742f6c4-d05d-4920-821f-acca2496fc49	KHR	CURRENCY	Riel	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2781689c-a45e-4904-a41e-ff465504021c	KMF	CURRENCY	Comorian Franc	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c082cd75-4b93-4a5a-b534-d4e598da63c7	KPW	CURRENCY	North Korean Won	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
bc86fd48-a3f5-4c35-b394-7655b10d2c51	KRW	CURRENCY	Won	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
dfbd596b-41f6-4d7f-9c8d-bfa1b0f9d120	KWD	CURRENCY	Kuwaiti Dinar	1000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b01a5bca-c246-43b8-8a0c-ed99ed24c881	KYD	CURRENCY	Cayman Islands Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
be1c38de-d003-4d16-ba42-52ba67949dd0	KZT	CURRENCY	Tenge	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
051b72f9-6fe9-451c-b7b0-e9ed2e678a37	LAK	CURRENCY	Lao Kip	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
3f32ddae-6e4f-4b50-b382-a59a0b122ad4	LBP	CURRENCY	Lebanese Pound	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
a5d3f6d3-efda-4b9c-8be9-bda6f282d1ae	LKR	CURRENCY	Sri Lanka Rupee	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
3fbb95d8-662b-4e16-ab7b-a38bb33d5f18	LRD	CURRENCY	Liberian Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
866af6a0-b7db-4cb7-8ca0-c5ecb55c158c	LSL	CURRENCY	Loti	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
deb71d64-b9ef-487b-b612-d9216e1099c9	LYD	CURRENCY	Libyan Dinar	1000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b48a3698-c66b-434a-a735-b01f7b6e3f77	MAD	CURRENCY	Moroccan Dirham	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f892390f-f79b-444d-aeef-68974e0c607d	MDL	CURRENCY	Moldovan Leu	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
d06c3fa0-a847-4845-a58d-225f60c0b49b	MGA	CURRENCY	Malagasy Ariary	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
72a7737c-e728-4883-b6b6-44dd3344b55c	MKD	CURRENCY	Denar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f4b3baa3-069f-44d3-9d36-bc0dcc4a5096	MMK	CURRENCY	Kyat	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
a1299a0d-ceda-4f15-a566-722752b94692	MNT	CURRENCY	Tugrik	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
25b3ca6d-e2cf-4991-b0ba-6f6ad4f8a2e6	MOP	CURRENCY	Pataca	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
4d756602-cf75-448e-bfa7-5ae09401455e	MRU	CURRENCY	Ouguiya	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f68c788a-10fe-420b-9342-3784e7ed749a	MUR	CURRENCY	Mauritius Rupee	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
888cec98-0a7f-42df-a11f-63c2bf976e75	MVR	CURRENCY	Rufiyaa	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
048921b8-86fd-422a-b031-95e785de4313	MWK	CURRENCY	Malawi Kwacha	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
901968a0-0d8f-4de1-90a9-434c956ddb06	MXN	CURRENCY	Mexican Peso	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
10d82dc7-c9f0-46c8-a88d-b7d5ed6bbb9f	MXV	CURRENCY	Mexican Unidad de Inversion (UDI)	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
35c4e11e-cbf4-44b8-a92d-5e95c653b54e	MYR	CURRENCY	Malaysian Ringgit	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8a1cc8cf-36ac-40d0-a8da-0f9fc813f3b5	MZN	CURRENCY	Mozambique Metical	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2d367282-b1d6-44d5-b4ce-61e94bed3e32	NAD	CURRENCY	Namibia Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
982db19c-de27-4d00-b190-2d8ec018bfdb	NGN	CURRENCY	Naira	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
3f6db5e2-e207-4df0-8244-1a4741c0d407	NIO	CURRENCY	Cordoba Oro	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
6e28848a-e733-41aa-a358-3e11425a8c04	NOK	CURRENCY	Norwegian Krone	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
891d1b84-8864-4f3e-b864-8e2045030fc9	NPR	CURRENCY	Nepalese Rupee	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
cab5a79d-8991-4304-b517-212395b857a4	NZD	CURRENCY	New Zealand Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
280f4b0f-c919-435e-9b3a-0d4000aaf3da	OMR	CURRENCY	Rial Omani	1000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
bc6a3f0b-ce3b-4998-b4ab-339e67aa0834	PAB	CURRENCY	Balboa	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
5c2794e5-7092-41b0-9647-de93c314e91a	PEN	CURRENCY	Sol	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
70bcf21e-35d6-4f96-8ef5-fc0e990bf00f	PGK	CURRENCY	Kina	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8c9f0aa9-6b85-4ae3-9a91-76b042329ead	PHP	CURRENCY	Philippine Peso	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
69389c9c-4e49-4d8d-a27f-540bd2f086b2	PKR	CURRENCY	Pakistan Rupee	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
1fbcb896-1482-4cf0-9821-8a7d2b074ac8	PLN	CURRENCY	Zloty	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
7a02ba3a-bf31-4b2b-877f-c7fbfdb177a0	PYG	CURRENCY	Guarani	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
54c19c3f-a513-4fdb-b179-a21940b6f016	QAR	CURRENCY	Qatari Rial	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
7c90f26a-5a30-4426-9452-451321480eb4	RON	CURRENCY	Romanian Leu	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b827dd73-5db7-489b-a230-1a5beb30d6a7	RSD	CURRENCY	Serbian Dinar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b0eef750-5b54-4e5d-b3e0-a9db50ebd145	RUB	CURRENCY	Russian Ruble	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
79da5878-f32e-4fd2-8048-8a17e49efceb	RWF	CURRENCY	Rwanda Franc	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
94f901dd-6767-4cec-a217-403abf495d5c	SAR	CURRENCY	Saudi Riyal	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
0a59f76e-5098-4c3d-bbca-e6746440c4a8	SBD	CURRENCY	Solomon Islands Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
39cc2c48-6348-48e9-b8ba-13c218d321ed	SCR	CURRENCY	Seychelles Rupee	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
1207eeef-1ef5-447c-9cb2-e59f3019511c	SDG	CURRENCY	Sudanese Pound	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
3d8f382c-329f-47cb-8481-7fbaf0dca079	SEK	CURRENCY	Swedish Krona	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
0c207e7a-30ba-4ef4-95fa-7d7d0fc97594	SGD	CURRENCY	Singapore Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
101534d5-c07b-456d-9d81-0ce8ac7301aa	SHP	CURRENCY	Saint Helena Pound	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b65d27a2-a68d-405a-bb2c-1897dbba56d8	SLE	CURRENCY	Leone	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
ebe9f43c-1711-42dd-af50-d3f531ab35d5	SOS	CURRENCY	Somali Shilling	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
44003bac-0cf2-4bc0-bcd3-7dc8b4cbea43	SRD	CURRENCY	Surinam Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
1678b8aa-5dfc-4031-b08c-7de8ddcbb8c7	SSP	CURRENCY	South Sudanese Pound	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c2868140-9499-4f5c-ac85-7a8c1a7a1b27	STN	CURRENCY	Dobra	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8c3028ca-72ca-46ba-aa90-2acb316c5f2c	SVC	CURRENCY	El Salvador Colon	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f083d48b-c908-4641-a238-bf33839ece84	SYP	CURRENCY	Syrian Pound	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
771a3376-4d29-475f-b7c3-d9d61b288f96	SZL	CURRENCY	Lilangeni	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2e4caff8-b722-4def-868f-0ec7aff3771c	THB	CURRENCY	Baht	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
373f8885-19d6-4310-b642-145048462e20	TJS	CURRENCY	Somoni	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
11bf792b-ddbc-49c1-97f7-df73b09acac1	TMT	CURRENCY	Turkmenistan New Manat	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
6ab03780-3e19-4596-aeb1-ffa34bf7c994	TND	CURRENCY	Tunisian Dinar	1000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
9d82cddc-e635-4575-895d-60c9bf7b3448	TOP	CURRENCY	Pa’anga	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
9e5951a8-2fae-4aa1-8e65-de3f9a8d16c7	TRY	CURRENCY	Turkish Lira	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
653ebf3a-3397-4fc5-832a-dca451fc3777	TTD	CURRENCY	Trinidad and Tobago Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
d9920c1d-5e53-4f4f-aacf-f6b528d34d06	TWD	CURRENCY	New Taiwan Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
9b10c87e-968e-43a1-897c-553c6e43ab67	TZS	CURRENCY	Tanzanian Shilling	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8799c214-dfda-4c64-a08c-7b4b30571aef	UAH	CURRENCY	Hryvnia	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
40b723ce-5943-4fe1-ba60-62c71ed54645	UGX	CURRENCY	Uganda Shilling	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
35e314f0-defc-4a84-86fe-6b6743f83837	USD	CURRENCY	US Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
0f5ef465-adf4-49e4-8e93-416b870a377c	USN	CURRENCY	US Dollar (Next day)	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
b5f403d2-deb6-444c-9966-b5805d3a21eb	UYI	CURRENCY	Uruguay Peso en Unidades Indexadas (UI)	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
9dff5b4c-2398-430f-873b-10f51f090e37	UYU	CURRENCY	Peso Uruguayo	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
1871b723-55da-45e9-9eb7-4c708ae744d2	UYW	CURRENCY	Unidad Previsional	10000	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
984c3375-32af-48bf-bead-811fafecb0bb	UZS	CURRENCY	Uzbekistan Sum	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
ae213692-6fe9-4b52-8764-5a384c852779	VED	CURRENCY	Bolívar Soberano	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c576d408-6f8a-4fa5-a1c7-4ac69153fbb0	VES	CURRENCY	Bolívar Soberano	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8949b528-5c43-4387-8f59-eaf405083b40	VND	CURRENCY	Dong	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
9147b469-8be1-479f-a78e-b76ffea20181	VUV	CURRENCY	Vatu	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
22e3eac1-0c59-4426-afbc-0cb4c105be67	WST	CURRENCY	Tala	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
42c289bd-a967-4301-8f97-6dc94fa90441	XAD	CURRENCY	Arab Accounting Dinar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
1660e5e1-baa6-4a01-8892-25a8384be550	XAF	CURRENCY	CFA Franc BEAC	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
23d175df-df83-44a6-8977-3692dc51e343	XAG	CURRENCY	Silver	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c8bdf2b1-7427-4ed4-9cd8-db0b270a60ec	XAU	CURRENCY	Gold	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
604ce49c-e3a2-4f07-8400-2b38dd139b5a	XBA	CURRENCY	Bond Markets Unit European Composite Unit (EURCO)	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
114e9da7-8bdd-4964-84c8-55b043af5aab	XBB	CURRENCY	Bond Markets Unit European Monetary Unit (E.M.U.-6)	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
83b3de23-b0da-4b55-9449-ab38f6f783a0	XBC	CURRENCY	Bond Markets Unit European Unit of Account 9 (E.U.A.-9)	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
8e3775a8-acce-47d4-abd5-bc2dbd851db4	XBD	CURRENCY	Bond Markets Unit European Unit of Account 17 (E.U.A.-17)	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c6cfa046-e558-4a4f-b935-c7e3f42fd6fb	XCD	CURRENCY	East Caribbean Dollar	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
9172b48d-cc3e-4a72-8dc8-1dc12b22daa1	XCG	CURRENCY	Caribbean Guilder	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
a9c79739-3dab-4bcc-a785-3abfcb08f8db	XDR	CURRENCY	SDR (Special Drawing Right)	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
abb5362a-9c91-423c-bd73-69820aff0bd1	XOF	CURRENCY	CFA Franc BCEAO	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
4c47f9be-6392-4bf2-b6f6-90936999e5da	XPD	CURRENCY	Palladium	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c68e0d96-c427-4b67-9795-e028372c1984	XPF	CURRENCY	CFP Franc	1	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
d09ce86d-5995-41c6-95f5-a2cd5cfe9242	XPT	CURRENCY	Platinum	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
5d9f473a-2ba7-44f1-b622-a53d509a8f56	XSU	CURRENCY	Sucre	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f0e2bfad-d449-4c11-8ca0-c9842062c3a3	XTS	CURRENCY	Codes specifically reserved for testing purposes	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
e07eac1a-9be2-421b-92aa-7e4fe9d2e6d2	XUA	CURRENCY	ADB Unit of Account	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
5cfb26fb-be9e-439c-945f-28065e82fcd1	XXX	CURRENCY	The codes assigned for transactions where no currency is involved	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
ed828081-a4cf-4454-a712-c347bf3d0ae0	YER	CURRENCY	Yemeni Rial	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
4aaa3905-17d8-4015-9df8-ceaef55dce87	ZAR	CURRENCY	Rand	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
2ecd166f-af28-4bf8-a0c0-65dd79302cc9	ZMW	CURRENCY	Zambian Kwacha	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
f71e23d8-af81-483f-9de7-0d480d870af7	ZWG	CURRENCY	Zimbabwe Gold	100	t	2026-02-06 11:54:24.93737-06	2026-02-06 11:54:24.93737-06	0	\N
c48f45eb-dfbd-4eb7-b3df-d86ad639316f	BTC	CRYPTO	Bitcoin	100000000	t	2026-02-06 12:12:44.655223-06	2026-02-06 12:12:44.655223-06	0	\N
f4c8f8f6-5723-4ae9-8ae7-a0da754d512e	ETH	CRYPTO	Ethereum	1000000000000000000	t	2026-02-06 12:12:44.655223-06	2026-02-06 12:12:44.655223-06	0	\N
258f9655-b209-4833-8d01-ceb061077d25	USDT	CRYPTO	Tether USDt	1000000	t	2026-02-06 12:12:44.655223-06	2026-02-06 12:12:44.655223-06	0	\N
2f8b9075-7c75-4a49-86d3-54aaddc81d46	USDC	CRYPTO	USD Coin	1000000	t	2026-02-06 12:12:44.655223-06	2026-02-06 12:12:44.655223-06	0	\N
\.


--
-- TOC entry 4153 (class 0 OID 16951)
-- Dependencies: 259
-- Data for Name: enum_label; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.enum_label (enum_name, enum_value, locale, label, description) FROM stdin;
\.


--
-- TOC entry 4142 (class 0 OID 16530)
-- Dependencies: 248
-- Data for Name: ledger; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ledger (id, owner_id, name, currency_code, "precision", template, is_active, closed_at, created_at, currency_commodity_id, root_account_id, updated_at, revision, deleted_at, coa_template_id) FROM stdin;
\.


--
-- TOC entry 4138 (class 0 OID 16428)
-- Dependencies: 244
-- Data for Name: ledger_owner; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ledger_owner (id, email, email_verified, password_hash, display_name, is_active, created_at, updated_at, last_login_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4143 (class 0 OID 16567)
-- Dependencies: 249
-- Data for Name: payee; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payee (id, ledger_id, name, is_active, created_at, updated_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4145 (class 0 OID 16655)
-- Dependencies: 251
-- Data for Name: price; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.price (id, commodity_id, currency_id, date, source, type, value_denom, value_num, created_at, updated_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4149 (class 0 OID 16829)
-- Dependencies: 255
-- Data for Name: recurrence; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recurrence (id, created_at, mult, period_start, period_type, weekend_adjust, scheduled_transaction_id, updated_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4150 (class 0 OID 16855)
-- Dependencies: 256
-- Data for Name: scheduled_split; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scheduled_split (id, action, created_at, memo, side, value_denom, value_num, scheduled_transaction_id, account_id, updated_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4148 (class 0 OID 16774)
-- Dependencies: 254
-- Data for Name: scheduled_transaction; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scheduled_transaction (id, ledger_id, adv_creation, adv_notify, auto_create, auto_notify, created_at, enabled, end_date, instance_count, is_active, last_occur, name, num_occur, rem_occur, start_date, currency_commodity_id, payee_id, template_root_account_id, updated_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4147 (class 0 OID 16731)
-- Dependencies: 253
-- Data for Name: split; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.split (id, action, amount, created_at, memo, quantity_denom, quantity_num, reconcile_date, reconcile_state, side, value_denom, value_num, account_id, transaction_id, updated_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 4146 (class 0 OID 16691)
-- Dependencies: 252
-- Data for Name: transaction; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transaction (id, ledger_id, created_at, enter_date, is_voided, memo, num, post_date, status, currency_commodity_id, payee_id, updated_at, revision, deleted_at) FROM stdin;
\.


--
-- TOC entry 3927 (class 2606 OID 16626)
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- TOC entry 3913 (class 2606 OID 16505)
-- Name: account_type account_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_type
    ADD CONSTRAINT account_type_pkey PRIMARY KEY (id);


--
-- TOC entry 3908 (class 2606 OID 16469)
-- Name: auth_identity auth_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_pkey PRIMARY KEY (id);


--
-- TOC entry 3910 (class 2606 OID 16471)
-- Name: auth_identity auth_identity_provider_provider_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_provider_provider_user_id_key UNIQUE (provider, provider_user_id);


--
-- TOC entry 3954 (class 2606 OID 16910)
-- Name: coa_template coa_template_code_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coa_template
    ADD CONSTRAINT coa_template_code_version_key UNIQUE (code, version);


--
-- TOC entry 3958 (class 2606 OID 16932)
-- Name: coa_template_node coa_template_node_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coa_template_node
    ADD CONSTRAINT coa_template_node_pkey PRIMARY KEY (id);


--
-- TOC entry 3960 (class 2606 OID 16934)
-- Name: coa_template_node coa_template_node_template_id_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coa_template_node
    ADD CONSTRAINT coa_template_node_template_id_code_key UNIQUE (template_id, code);


--
-- TOC entry 3956 (class 2606 OID 16908)
-- Name: coa_template coa_template_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coa_template
    ADD CONSTRAINT coa_template_pkey PRIMARY KEY (id);


--
-- TOC entry 3917 (class 2606 OID 16529)
-- Name: commodity commodity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commodity
    ADD CONSTRAINT commodity_pkey PRIMARY KEY (id);


--
-- TOC entry 3965 (class 2606 OID 16961)
-- Name: enum_label enum_label_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enum_label
    ADD CONSTRAINT enum_label_pkey PRIMARY KEY (enum_name, enum_value, locale);


--
-- TOC entry 3904 (class 2606 OID 16451)
-- Name: ledger_owner ledger_owner_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ledger_owner
    ADD CONSTRAINT ledger_owner_email_key UNIQUE (email);


--
-- TOC entry 3906 (class 2606 OID 16449)
-- Name: ledger_owner ledger_owner_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ledger_owner
    ADD CONSTRAINT ledger_owner_pkey PRIMARY KEY (id);


--
-- TOC entry 3920 (class 2606 OID 16555)
-- Name: ledger ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_pkey PRIMARY KEY (id);


--
-- TOC entry 3923 (class 2606 OID 16588)
-- Name: payee payee_ledger_id_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payee
    ADD CONSTRAINT payee_ledger_id_name_key UNIQUE (ledger_id, name);


--
-- TOC entry 3925 (class 2606 OID 16586)
-- Name: payee payee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payee
    ADD CONSTRAINT payee_pkey PRIMARY KEY (id);


--
-- TOC entry 3933 (class 2606 OID 16679)
-- Name: price price_commodity_id_currency_id_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price
    ADD CONSTRAINT price_commodity_id_currency_id_date_key UNIQUE (commodity_id, currency_id, date);


--
-- TOC entry 3935 (class 2606 OID 16677)
-- Name: price price_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price
    ADD CONSTRAINT price_pkey PRIMARY KEY (id);


--
-- TOC entry 3948 (class 2606 OID 16848)
-- Name: recurrence recurrence_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recurrence
    ADD CONSTRAINT recurrence_pkey PRIMARY KEY (id);


--
-- TOC entry 3952 (class 2606 OID 16877)
-- Name: scheduled_split scheduled_split_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduled_split
    ADD CONSTRAINT scheduled_split_pkey PRIMARY KEY (id);


--
-- TOC entry 3945 (class 2606 OID 16807)
-- Name: scheduled_transaction scheduled_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_pkey PRIMARY KEY (id);


--
-- TOC entry 3942 (class 2606 OID 16761)
-- Name: split split_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.split
    ADD CONSTRAINT split_pkey PRIMARY KEY (id);


--
-- TOC entry 3938 (class 2606 OID 16714)
-- Name: transaction transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_pkey PRIMARY KEY (id);


--
-- TOC entry 3914 (class 1259 OID 17164)
-- Name: commodity_namespace_mnemonic_uq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX commodity_namespace_mnemonic_uq ON public.commodity USING btree (namespace, mnemonic);


--
-- TOC entry 3915 (class 1259 OID 17096)
-- Name: commodity_namespace_mnemonic_ux; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX commodity_namespace_mnemonic_ux ON public.commodity USING btree (namespace, mnemonic) WHERE (deleted_at IS NULL);


--
-- TOC entry 3928 (class 1259 OID 16647)
-- Name: idx_account_ledger; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_account_ledger ON public.account USING btree (ledger_id);


--
-- TOC entry 3929 (class 1259 OID 16648)
-- Name: idx_account_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_account_parent ON public.account USING btree (parent_id);


--
-- TOC entry 3911 (class 1259 OID 16477)
-- Name: idx_auth_identity_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_auth_identity_owner ON public.auth_identity USING btree (ledger_owner_id);


--
-- TOC entry 3961 (class 1259 OID 16942)
-- Name: idx_coa_node_template_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_coa_node_template_code ON public.coa_template_node USING btree (template_id, code);


--
-- TOC entry 3962 (class 1259 OID 16941)
-- Name: idx_coa_node_template_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_coa_node_template_level ON public.coa_template_node USING btree (template_id, level);


--
-- TOC entry 3963 (class 1259 OID 16940)
-- Name: idx_coa_node_template_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_coa_node_template_parent ON public.coa_template_node USING btree (template_id, parent_code);


--
-- TOC entry 3918 (class 1259 OID 16566)
-- Name: idx_ledger_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ledger_owner ON public.ledger USING btree (owner_id);


--
-- TOC entry 3921 (class 1259 OID 16594)
-- Name: idx_payee_ledger; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payee_ledger ON public.payee USING btree (ledger_id);


--
-- TOC entry 3931 (class 1259 OID 16690)
-- Name: idx_price_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_price_date ON public.price USING btree (date);


--
-- TOC entry 3946 (class 1259 OID 16854)
-- Name: idx_recur_schedtx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_recur_schedtx ON public.recurrence USING btree (scheduled_transaction_id);


--
-- TOC entry 3949 (class 1259 OID 16889)
-- Name: idx_schedsplit_account; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedsplit_account ON public.scheduled_split USING btree (account_id);


--
-- TOC entry 3950 (class 1259 OID 16888)
-- Name: idx_schedsplit_schedtx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedsplit_schedtx ON public.scheduled_split USING btree (scheduled_transaction_id);


--
-- TOC entry 3943 (class 1259 OID 16828)
-- Name: idx_schedtx_ledger; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedtx_ledger ON public.scheduled_transaction USING btree (ledger_id);


--
-- TOC entry 3939 (class 1259 OID 16773)
-- Name: idx_split_account; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_split_account ON public.split USING btree (account_id);


--
-- TOC entry 3940 (class 1259 OID 16772)
-- Name: idx_split_tx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_split_tx ON public.split USING btree (transaction_id);


--
-- TOC entry 3936 (class 1259 OID 16730)
-- Name: idx_tx_ledger_post_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tx_ledger_post_date ON public.transaction USING btree (ledger_id, post_date);


--
-- TOC entry 3930 (class 1259 OID 16649)
-- Name: uq_account_ledger_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX uq_account_ledger_code ON public.account USING btree (ledger_id, code) WHERE (code IS NOT NULL);


--
-- TOC entry 3972 (class 2606 OID 16632)
-- Name: account account_account_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_account_type_id_fkey FOREIGN KEY (account_type_id) REFERENCES public.account_type(id) ON DELETE SET NULL;


--
-- TOC entry 3973 (class 2606 OID 16637)
-- Name: account account_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES public.commodity(id) ON DELETE SET NULL;


--
-- TOC entry 3974 (class 2606 OID 16627)
-- Name: account account_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES public.ledger(id) ON DELETE CASCADE;


--
-- TOC entry 3975 (class 2606 OID 16642)
-- Name: account account_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.account(id) ON DELETE SET NULL;


--
-- TOC entry 3966 (class 2606 OID 16472)
-- Name: auth_identity auth_identity_ledger_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_ledger_owner_id_fkey FOREIGN KEY (ledger_owner_id) REFERENCES public.ledger_owner(id) ON DELETE CASCADE;


--
-- TOC entry 3990 (class 2606 OID 16935)
-- Name: coa_template_node coa_template_node_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coa_template_node
    ADD CONSTRAINT coa_template_node_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.coa_template(id) ON DELETE CASCADE;


--
-- TOC entry 3967 (class 2606 OID 16650)
-- Name: ledger fk_ledger_root_account; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT fk_ledger_root_account FOREIGN KEY (root_account_id) REFERENCES public.account(id) ON DELETE SET NULL;


--
-- TOC entry 3968 (class 2606 OID 16943)
-- Name: ledger ledger_coa_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_coa_template_id_fkey FOREIGN KEY (coa_template_id) REFERENCES public.coa_template(id) ON DELETE SET NULL;


--
-- TOC entry 3969 (class 2606 OID 16561)
-- Name: ledger ledger_currency_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_currency_commodity_id_fkey FOREIGN KEY (currency_commodity_id) REFERENCES public.commodity(id) ON DELETE SET NULL;


--
-- TOC entry 3970 (class 2606 OID 16556)
-- Name: ledger ledger_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.ledger_owner(id) ON DELETE RESTRICT;


--
-- TOC entry 3971 (class 2606 OID 16589)
-- Name: payee payee_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payee
    ADD CONSTRAINT payee_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES public.ledger(id) ON DELETE CASCADE;


--
-- TOC entry 3976 (class 2606 OID 16680)
-- Name: price price_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price
    ADD CONSTRAINT price_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES public.commodity(id) ON DELETE CASCADE;


--
-- TOC entry 3977 (class 2606 OID 16685)
-- Name: price price_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price
    ADD CONSTRAINT price_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.commodity(id) ON DELETE RESTRICT;


--
-- TOC entry 3987 (class 2606 OID 16849)
-- Name: recurrence recurrence_scheduled_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recurrence
    ADD CONSTRAINT recurrence_scheduled_transaction_id_fkey FOREIGN KEY (scheduled_transaction_id) REFERENCES public.scheduled_transaction(id) ON DELETE CASCADE;


--
-- TOC entry 3988 (class 2606 OID 16883)
-- Name: scheduled_split scheduled_split_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduled_split
    ADD CONSTRAINT scheduled_split_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id) ON DELETE RESTRICT;


--
-- TOC entry 3989 (class 2606 OID 16878)
-- Name: scheduled_split scheduled_split_scheduled_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduled_split
    ADD CONSTRAINT scheduled_split_scheduled_transaction_id_fkey FOREIGN KEY (scheduled_transaction_id) REFERENCES public.scheduled_transaction(id) ON DELETE CASCADE;


--
-- TOC entry 3983 (class 2606 OID 16813)
-- Name: scheduled_transaction scheduled_transaction_currency_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_currency_commodity_id_fkey FOREIGN KEY (currency_commodity_id) REFERENCES public.commodity(id) ON DELETE SET NULL;


--
-- TOC entry 3984 (class 2606 OID 16808)
-- Name: scheduled_transaction scheduled_transaction_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES public.ledger(id) ON DELETE CASCADE;


--
-- TOC entry 3985 (class 2606 OID 16818)
-- Name: scheduled_transaction scheduled_transaction_payee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES public.payee(id) ON DELETE SET NULL;


--
-- TOC entry 3986 (class 2606 OID 16823)
-- Name: scheduled_transaction scheduled_transaction_template_root_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduled_transaction
    ADD CONSTRAINT scheduled_transaction_template_root_account_id_fkey FOREIGN KEY (template_root_account_id) REFERENCES public.account(id) ON DELETE SET NULL;


--
-- TOC entry 3981 (class 2606 OID 16762)
-- Name: split split_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.split
    ADD CONSTRAINT split_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id) ON DELETE RESTRICT;


--
-- TOC entry 3982 (class 2606 OID 16767)
-- Name: split split_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.split
    ADD CONSTRAINT split_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transaction(id) ON DELETE CASCADE;


--
-- TOC entry 3978 (class 2606 OID 16720)
-- Name: transaction transaction_currency_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_currency_commodity_id_fkey FOREIGN KEY (currency_commodity_id) REFERENCES public.commodity(id) ON DELETE SET NULL;


--
-- TOC entry 3979 (class 2606 OID 16715)
-- Name: transaction transaction_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES public.ledger(id) ON DELETE CASCADE;


--
-- TOC entry 3980 (class 2606 OID 16725)
-- Name: transaction transaction_payee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES public.payee(id) ON DELETE SET NULL;


-- Completed on 2026-02-23 11:41:22 CST

--
-- PostgreSQL database dump complete
--

\unrestrict hVMEVzJa2fNtj2Bd4qNl6GaIbG19ToD1XjIwUPw8Pdw1s4cFKwmhDPd3gsdG2uy

