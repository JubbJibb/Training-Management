# Future migrations (do not run yet)

These migrations are for the **database redesign** (normalized schema).  
They are **not** in `db/migrate` on purpose: running them would drop the `attendees` table and break the current app.

**When you are ready to switch to the new schema:**

1. Update the application to use `Attendance`, `Payment`, `Document`, `PromotionApplication`, `Instructor`, `ClassPricing` (and optionally Customer `first_name`/`last_name`/`company_name`/`province`).
2. Back up the database.
3. Copy the migration file back to `db/migrate/`.
4. Run `bin/rails db:migrate`.

See `docs/DATABASE_ER_DIAGRAM.md` for the target ER diagram.
