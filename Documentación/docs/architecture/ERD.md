# ER Diagram (auto-generated)

```mermaid
erDiagram
  public_account {
     id
     ledger_id
     account_role
     code
     commodity_scu
     created_at
     is_active
     is_hidden
     is_placeholder
     kind
     name
     non_std_scu
  }
  public_account_type {
     id
     code
     name
     standard
     kind
     normal_balance
     sort_order
     is_active
     created_at
     updated_at
     revision
     deleted_at
  }
  public_auth_identity {
     id
     ledger_owner_id
     provider
     provider_user_id
     provider_email
     email_verified
     created_at
     last_login_at
     revision
     deleted_at
  }
  public_coa_template {
     id
     code
     name
     description
     country
     locale
     industry
     version
     is_active
     created_at
     updated_at
  }
  public_coa_template_node {
     id
     template_id
     code
     parent_code
     name
     level
     kind
     role
     is_placeholder
     account_type_code
     created_at
     updated_at
  }
  public_commodity {
     id
     mnemonic
     namespace
     full_name
     fraction
     is_active
     created_at
     updated_at
     revision
     deleted_at
  }
  public_enum_label {
     enum_name
     enum_value
     locale
     label
     description
  }
  public_ledger {
     id
     owner_id
     name
     currency_code
     precision
     template
     is_active
     closed_at
     created_at
     currency_commodity_id
     root_account_id
     coa_template_id
  }
  public_ledger_owner {
     id
     email
     email_verified
     password_hash
     display_name
     is_active
     created_at
     updated_at
     last_login_at
     revision
     deleted_at
  }
  public_payee {
     id
     ledger_id
     name
     is_active
     created_at
     updated_at
     revision
     deleted_at
  }
  public_price {
     id
     commodity_id
     currency_id
     date
     source
     type
     value_denom
     value_num
     created_at
     updated_at
     revision
     deleted_at
  }
  public_recurrence {
     id
     created_at
     mult
     period_start
     period_type
     weekend_adjust
     scheduled_transaction_id
     updated_at
     revision
     deleted_at
  }
  public_scheduled_split {
     id
     action
     created_at
     memo
     side
     value_denom
     value_num
     scheduled_transaction_id
     account_id
     updated_at
     revision
     deleted_at
  }
  public_scheduled_transaction {
     id
     ledger_id
     adv_creation
     adv_notify
     auto_create
     auto_notify
     created_at
     enabled
     end_date
     instance_count
     is_active
     last_occur
  }
  public_split {
     id
     action
     amount
     created_at
     memo
     quantity_denom
     quantity_num
     reconcile_date
     reconcile_state
     side
     value_denom
     value_num
  }
  public_transaction {
     id
     ledger_id
     created_at
     enter_date
     is_voided
     memo
     num
     post_date
     status
     currency_commodity_id
     payee_id
     updated_at
  }
  public_account }o--|| public_account_type : "account_type_id->id"
  public_account }o--|| public_commodity : "commodity_id->id"
  public_account }o--|| public_ledger : "ledger_id->id"
  public_account }o--|| public_account : "parent_id->id"
  public_auth_identity }o--|| public_ledger_owner : "ledger_owner_id->id"
  public_coa_template_node }o--|| public_coa_template_node : "template_id, parent_code->template_id, code"
  public_coa_template_node }o--|| public_account_type : "account_type_code->code"
  public_coa_template_node }o--|| public_coa_template : "template_id->id"
  public_ledger }o--|| public_account : "root_account_id->id"
  public_ledger }o--|| public_coa_template : "coa_template_id->id"
  public_ledger }o--|| public_commodity : "currency_commodity_id->id"
  public_ledger }o--|| public_ledger_owner : "owner_id->id"
  public_payee }o--|| public_ledger : "ledger_id->id"
  public_price }o--|| public_commodity : "commodity_id->id"
  public_price }o--|| public_commodity : "currency_id->id"
  public_recurrence }o--|| public_scheduled_transaction : "scheduled_transaction_id->id"
  public_scheduled_split }o--|| public_account : "account_id->id"
  public_scheduled_split }o--|| public_scheduled_transaction : "scheduled_transaction_id->id"
  public_scheduled_transaction }o--|| public_commodity : "currency_commodity_id->id"
  public_scheduled_transaction }o--|| public_ledger : "ledger_id->id"
  public_scheduled_transaction }o--|| public_payee : "payee_id->id"
  public_scheduled_transaction }o--|| public_account : "template_root_account_id->id"
  public_split }o--|| public_account : "account_id->id"
  public_split }o--|| public_transaction : "transaction_id->id"
  public_transaction }o--|| public_commodity : "currency_commodity_id->id"
  public_transaction }o--|| public_ledger : "ledger_id->id"
  public_transaction }o--|| public_payee : "payee_id->id"
```
