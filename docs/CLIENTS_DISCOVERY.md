# Clients – Corporate Accounts & Client Analysis – Discovery

## Existing models / schema

- **customers**: id, name, email, company, billing_name, billing_address, participant_type (not in schema; may be on attendee only), tax_id, phone, address, name_thai. No `companies` table. No `acquisition_channel`.
- **attendees**: customer_id, training_class_id, participant_type (Indi/Corp), payment_status (Pending/Paid), due_date, total_amount, document_status (QT/INV/Receipt), source_channel, status (attendee/potential), company (denormalized). Methods: total_final_price, total_price_before_vat. Scopes: attendees, corp, indi.
- **training_classes**: date, title, cost, price; association to class_expenses.
- **class_expenses**: amount, category, training_class_id.

## Existing routes / nav

- **Routes**: `get "customers", to: redirect("/admin/customers")`; `namespace :admin` has `resources :customers`.
- **Nav (Clients)**: "Client Directory" → admin_customers_path; "Corporate Accounts" → admin_customers_path(segment: "Corp"). No dedicated /clients namespace.

## Gaps

1. **No companies table** – Corporate accounts implemented as a query layer: group Corp attendees (or customers) by company name (customer.company_name / attendee.company). Use first customer_id in group as account id for show page.
2. **No acquisition_channel on customers** – Add `customers.acquisition_channel` (string, nullable), backfill "unknown", for Client Analysis channel filter and charts. Alternatively derive from attendee.source_channel per customer (no DB change).
3. **Indexes** – attendees: customer_id, training_class_id, due_date, payment_status. Add index on (participant_type, due_date) or similar if needed for corp queries.

## Decisions

- **Corporate account id**: Use representative `customer_id` (first customer in group by company_name). Show page loads that customer, resolves company_name, fetches all customers with same company_name (Corp), aggregates from their attendees.
- **Channel**: Add migration `customers.acquisition_channel`; backfill "unknown"; use in Client Analysis. Keep using attendee.source_channel for lead/conversion by channel where applicable.
- **Client Directory link**: Keep "Client Directory" pointing to `/admin/customers` (or `/customers` redirect). Add "Corporate Accounts" → `/clients/corporate_accounts`, "Client Analysis" → `/clients/analysis`.
