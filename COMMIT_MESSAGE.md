# Commit Message

## Feature: Separate Class Attendees and Potential Customers with Status Management

### Summary
Added status field to attendees to separate registered attendees from potential customers, with ability to move between statuses. Includes promotion/discount system, settings page, and improved class management UI.

### Changes

#### Database
- Added `status` field to `attendees` table (default: "attendee")
- Migration: `20260211050655_add_status_to_attendees.rb`
- Created `promotions` table for discount management
- Created `attendee_promotions` join table for many-to-many relationship
- Created rake task to migrate existing attendees to potential customers

#### Models
- **Attendee**: 
  - Added `status` validation (attendee/potential)
  - Added scopes: `attendees` and `potential_customers`
  - Added `has_many :promotions` relationship
  - Added price calculation methods with discount support
  - Maintains all existing functionality
- **Promotion**:
  - Supports 3 discount types: percentage, fixed, buy_x_get_y
  - Methods for calculating discounts and displaying descriptions

#### Controllers
- **TrainingClassesController**:
  - Updated `show` action to separate attendees and potential customers
  - Changed sorting to `order(date: :asc)` for upcoming classes first
- **AttendeesController**:
  - Added `move_to_potential` and `move_to_attendee` actions
  - Updated `attendee_params` to permit `status` and `promotion_ids` fields
  - Added promotions loading for new/edit forms
- **SettingsController**:
  - Full CRUD for managing promotions
  - Supports creating/editing/deleting discount types

#### Views
- **training_classes/show.html.erb**:
  - Split Participants tab into 2 separate tabs:
    - Tab 1: Class Attendees (registered attendees)
    - Tab 2: Potential Customers (leads/prospects)
  - Added move buttons with icon-only design matching Edit/Delete buttons
  - Updated tab navigation (now 4 tabs: Attendees, Potential, Documents, Finance)
  - Added JavaScript for automatic tab switching after move actions
- **attendees/new.html.erb** and **attendees/edit.html.erb**:
  - Added status dropdown field
  - Added promotion selection checkboxes
  - Added real-time price calculation with discount summary
  - Shows base price, total discount, and final price
- **settings/**:
  - Index page listing all promotions
  - New/Edit forms for promotion management
  - Supports all discount types with helpful descriptions

#### Routes
- Added member routes for `move_to_potential` and `move_to_attendee` actions
- Added settings routes for promotion management
- Added link to Settings in admin navbar

#### Tasks
- Created `lib/tasks/migrate_attendees.rake` for data migration

### Features
1. **Status Management**: Attendees can be marked as "attendee" or "potential"
2. **Move Functionality**: One-click buttons to move between statuses
3. **Separate Views**: Clean separation of registered vs potential customers
4. **Data Preservation**: All information preserved when moving between statuses
5. **Icon-Only Buttons**: Compact design matching existing UI patterns
6. **Promotion/Discount System**:
   - Support for percentage, fixed amount, and buy-x-get-y discounts
   - Multiple promotions can be applied to one attendee
   - Real-time price calculation
   - Settings page for managing promotions
7. **Default Promotions**: Seed data includes common promotions (Earlybird, Post and Share, etc.)

### Migration
- Existing attendees automatically migrated to "potential" status
- New attendees default to "attendee" status

### UI/UX Improvements
- Consistent button sizing (icon-only for move actions)
- Clear visual separation between tabs
- Tooltips for icon buttons
- Automatic tab switching after move actions
