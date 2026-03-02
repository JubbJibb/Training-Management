module Admin
  class TrainingClassesController < ApplicationController
    include ActionView::RecordIdentifier
    layout "admin"
    
    def index
      @tab = params[:tab].presence || "upcoming"
      @filter_instructors = TrainingClass.distinct.pluck(:instructor).compact.sort
      @index_path = request.path
      load_training_classes_kpis
      load_training_classes_for_tab
    end
    
    def show
      @training_class = TrainingClass.find(params[:id])
      redirect_to admin_class_workspace_path(@training_class), status: :found
    end

    def finance
      @training_class = TrainingClass.find(params[:id])
      # When opened in full page (not Turbo Frame), go to Class Workspace finance section
      unless request.headers["Turbo-Frame"].to_s.present?
        redirect_to admin_class_workspace_finance_path(@training_class), status: :found and return
      end
      @finance_dashboard = ::Finance::ClassFinanceDashboardQuery.new(
        @training_class,
        type: params[:type].presence, status: params[:status].presence,
        expense_category: params[:expense_category].presence,
        expense_date_from: params[:expense_date_from].presence,
        expense_date_to: params[:expense_date_to].presence
      ).call
      render layout: false
    end
    
    def new
      @training_class = TrainingClass.new
      if params[:course_id].present?
        course = Course.find_by(id: params[:course_id])
        if course
          @course = course
          @training_class.title = course.title
          @training_class.description = course.description
          @training_class.max_attendees = course.capacity if course.capacity.present?
        end
      end
    end
    
    def create
      @training_class = TrainingClass.new(training_class_params)
      
      if @training_class.save
        redirect_to edit_admin_training_class_path(@training_class), notice: "Training class created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
      @training_class = TrainingClass.find(params[:id])
      tab = params[:tab].presence || "edit"
      # Merge with Class Workspace: redirect to same layout (sidebar + sections)
      redirect_to(
        case tab
        when "overview" then admin_class_workspace_overview_path(@training_class)
        when "attendees" then admin_class_workspace_attendees_path(@training_class)
        when "potential" then admin_class_workspace_leads_path(@training_class)
        when "documents" then admin_class_workspace_documents_path(@training_class)
        when "finance" then admin_class_workspace_finance_path(@training_class)
        else admin_class_workspace_edit_path(@training_class)
        end,
        status: :found
      )
    end
    
    def update
      @training_class = TrainingClass.find(params[:id])
      
      if @training_class.update(training_class_params)
        if params[:from_workspace].present?
          redirect_to admin_class_workspace_edit_path(@training_class), notice: "Training class updated successfully."
        else
          redirect_to edit_admin_training_class_path(@training_class, tab: params[:tab].presence), notice: "Training class updated successfully."
        end
      else
        if params[:from_workspace].present?
          @section = "edit"
          render "admin/class_workspace/edit", layout: "layouts/class_workspace", status: :unprocessable_entity
        else
          @attendees = @training_class.attendees.attendees.includes(:customer).order(:name)
          @potential_customers = @training_class.attendees.potential_customers.order(:name)
          @document_summary = DocumentSummaryService.new(@training_class.id).summary
          @finance_dashboard = ::Finance::ClassFinanceDashboardQuery.new(@training_class, type: params[:type].presence, status: params[:status].presence, expense_category: params[:expense_category].presence, expense_date_from: params[:expense_date_from].presence, expense_date_to: params[:expense_date_to].presence).call
          render :edit, status: :unprocessable_entity
        end
      end
    end
    
    def destroy
      @training_class = TrainingClass.find(params[:id])

      if @training_class.destroy
        redirect_to admin_training_classes_path, notice: "Training class deleted successfully."
      else
        redirect_to admin_training_classes_path, alert: "Failed to delete training class: #{@training_class.errors.full_messages.join(', ')}"
      end
    rescue => e
      redirect_to admin_training_classes_path, alert: "Error deleting training class: #{e.message}"
    end

    # Copy class: pre-fill new form from existing class (change date, time, instructor).
    def copy
      source = TrainingClass.find(params[:id])
      @training_class = source.dup
      @training_class.public_slug = nil
      @copy_from = source
      render :new
    end

    def toggle_public
      @training_class = TrainingClass.find(params[:id])
      new_state = if params.key?(:public_enabled)
        ActiveModel::Type::Boolean.new.cast(params[:public_enabled])
      else
        !@training_class.public_enabled?
      end
      @training_class.update!(public_enabled: new_state)
      if new_state && @training_class.public_slug.blank?
        @training_class.ensure_public_slug!
      end
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@training_class, :row),
            partial: "admin/training_classes/table_row",
            locals: {
              tc: @training_class,
              sort_column: @sort_column,
              sort_direction: @sort_direction,
              sort_params: request.query_parameters.slice("tab", "instructor", "date_from", "date_to", "class_type").compact,
              index_path: @index_path
            }
          ), status: :ok
        end
        format.html { redirect_to admin_training_classes_path, notice: (new_state ? "Public page enabled." : "Public page disabled.") }
      end
    end
    
    def update_related_links
      @training_class = TrainingClass.find(params[:id])
      raw = params[:related_links] || params["related_links"] || params.dig(:training_class, :related_links) || []
      links = raw.is_a?(Hash) ? raw.values : Array(raw)
      valid_links = links.filter_map do |link|
        next unless link.is_a?(Hash) || link.respond_to?(:to_h)
        h = link.respond_to?(:to_unsafe_h) ? link.to_unsafe_h : link
        label = (h["label"] || h[:label]).to_s.strip
        url = (h["url"] || h[:url]).to_s.strip
        next if label.blank? || url.blank?
        next unless url.match?(/\Ahttps?:\/\//i)
        { "label" => label, "url" => url, "type" => (h["type"] || h[:type]).presence || "External", "created_at" => (h["created_at"] || h[:created_at]).presence || Time.current.iso8601 }
      end
      @training_class.update!(related_links: valid_links)
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace("related-links-section", partial: "admin/training_classes/overview/related_links", locals: { training_class: @training_class }), status: :ok
      else
        response.headers["Turbo-Visit-Control"] = "reload"
        redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), notice: "Related links updated."
      end
    rescue ActiveRecord::RecordInvalid => e
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace("related-links-errors", partial: "admin/training_classes/overview/related_links_errors", locals: { errors: e.record.errors.full_messages }), status: :unprocessable_entity
      else
        redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), alert: e.record.errors.full_messages.join(", ")
      end
    end

    def update_checklist
      @training_class = TrainingClass.find(params[:id])
      raw = params[:checklist_items] || params["checklist_items"] || params.dig(:training_class, :checklist_items) || []
      items = raw.is_a?(Hash) ? raw.values : Array(raw)
      valid_items = items.filter_map do |item|
        next unless item.is_a?(Hash) || item.respond_to?(:to_h)
        h = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
        title = (h["title"] || h[:title]).to_s.strip
        next if title.blank?
        {
          "id" => (h["id"] || h[:id]).presence || SecureRandom.uuid,
          "title" => title,
          "done" => ActiveModel::Type::Boolean.new.cast(h["done"] || h[:done]),
          "due_date" => (h["due_date"] || h[:due_date]).presence,
          "owner" => (h["owner"] || h[:owner]).to_s.strip.presence,
          "priority" => (h["priority"] || h[:priority]).presence || "Med",
          "created_at" => (h["created_at"] || h[:created_at]).presence || Time.current.iso8601,
          "updated_at" => Time.current.iso8601
        }
      end
      @training_class.update!(checklist_items: valid_items)
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace("notes-checklist-card", partial: "admin/training_classes/overview/notes_checklist", locals: { training_class: @training_class }), status: :ok
      else
        response.headers["Turbo-Visit-Control"] = "reload"
        redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), notice: "Checklist updated."
      end
    rescue ActiveRecord::RecordInvalid => e
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace("checklist-errors", partial: "admin/training_classes/overview/checklist_errors", locals: { errors: e.record.errors.full_messages }), status: :unprocessable_entity
      else
        redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), alert: e.record.errors.full_messages.join(", ")
      end
    end

    def add_note
      @training_class = TrainingClass.find(params[:id])
      text = params[:note][:text].to_s.strip
      if text.blank?
        redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), alert: "Note text is required." and return
      end
      notes = @training_class.notes.dup
      author = current_user&.email.presence || "Admin"
      notes << { "id" => SecureRandom.uuid, "text" => text, "author" => author, "created_at" => Time.current.iso8601 }
      @training_class.update!(notes: notes)
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace("notes-tab-content", partial: "admin/training_classes/overview/notes_timeline", locals: { training_class: @training_class }), status: :ok
      else
        redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), notice: "Note added."
      end
    rescue => e
      redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), alert: "Failed to add note: #{e.message}"
    end

    def delete_note
      @training_class = TrainingClass.find(params[:id])
      note_id = params[:note_id].to_s
      return redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), alert: "Note ID required." if note_id.blank?
      notes = @training_class.notes.reject { |n| n["id"].to_s == note_id }
      @training_class.update!(notes: notes)
      redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), notice: "Note removed."
    rescue => e
      redirect_to edit_admin_training_class_path(@training_class, tab: "overview"), alert: "Failed to delete note: #{e.message}"
    end

    def send_email_to_all
      @training_class = TrainingClass.find(params[:id])
      subject = params[:subject]
      message = params[:message]
      
      if subject.blank? || message.blank?
        redirect_to edit_admin_training_class_path(@training_class), alert: "Subject and message are required."
        return
      end
      
      attendee_count = @training_class.attendees.attendees.count
      
      if attendee_count == 0
        redirect_to edit_admin_training_class_path(@training_class), alert: "No attendees to send email to."
        return
      end
      
      @training_class.attendees.attendees.each do |attendee|
        AttendeeMailer.send_custom(attendee, subject, message).deliver_now
      end
      
      redirect_to edit_admin_training_class_path(@training_class), notice: "Email sent to #{attendee_count} attendee(s)."
    rescue => e
      redirect_to edit_admin_training_class_path(@training_class), alert: "Error sending emails: #{e.message}"
    end
    
    private

    def load_training_classes_kpis
      upcoming = TrainingClass.upcoming
      @kpi_upcoming_count = upcoming.count
      # Average fill rate (upcoming classes with max_attendees only)
      with_max = upcoming.select { |tc| tc.max_attendees.present? && tc.max_attendees.positive? }
      @kpi_avg_fill_rate = if with_max.any?
        (with_max.sum { |tc| tc.fill_rate_percent || 0 }.to_f / with_max.size).round(0)
      else
        0
      end
      next_30_end = 30.days.from_now.to_date
      next_30_classes = upcoming.where("date <= ?", next_30_end)
      @kpi_seats_next_30 = next_30_classes.sum { |tc| tc.total_registered_seats }
      @kpi_revenue_forecast = next_30_classes.sum(&:net_revenue)
      past_30_start = 30.days.ago.to_date
      past_30_classes = TrainingClass.past.where("(end_date IS NOT NULL AND end_date >= ?) OR (end_date IS NULL AND date >= ?)", past_30_start, past_30_start)
      @kpi_past_30_revenue = past_30_classes.sum(&:net_revenue)
    end

    def load_training_classes_for_tab
      case @tab
      when "past"
        @training_classes = TrainingClass.past
        @empty_state_message = "No past classes."
        @empty_state_icon = "clock-history"
      when "cancelled"
        @training_classes = TrainingClass.cancelled
        @empty_state_message = "No cancelled classes."
        @empty_state_icon = "x-circle"
      else
        @training_classes = TrainingClass.upcoming
        @empty_state_message = "No upcoming classes. Create one to get started."
        @empty_state_icon = "calendar-x"
      end
      apply_tc_filters
      apply_tc_sort
      @sort_column = params[:sort].presence || "date"
      @sort_direction = params[:direction].presence == "desc" ? "desc" : "asc"
    end

    TC_SORTABLE_COLUMNS = %w[date title instructor fill revenue].freeze

    def apply_tc_sort
      sort = params[:sort].presence
      return unless sort.in?(TC_SORTABLE_COLUMNS)

      if %w[fill revenue].include?(sort)
        list = @training_classes.to_a
        direction = params[:direction].presence == "desc" ? -1 : 1
        @training_classes = list.sort do |a, b|
          va = sort == "fill" ? (a.fill_rate_percent || 0) : a.net_revenue
          vb = sort == "fill" ? (b.fill_rate_percent || 0) : b.net_revenue
          (va <=> vb) * direction
        end
      else
        order_sql = case sort
        when "date" then params[:direction].presence == "desc" ? "date DESC" : "date ASC"
        when "title" then params[:direction].presence == "desc" ? "title DESC" : "title ASC"
        when "instructor" then params[:direction].presence == "desc" ? "instructor DESC" : "instructor ASC"
        else "date ASC"
        end
        @training_classes = @training_classes.reorder(Arel.sql(order_sql))
      end
    end

    def apply_tc_filters
      @training_classes = @training_classes.where(public_enabled: true) if params[:class_type] == "public"
      @training_classes = @training_classes.where(public_enabled: false) if params[:class_type] == "private"
      @training_classes = @training_classes.where(instructor: params[:instructor]) if params[:instructor].present?
      if params[:date_from].present?
        @training_classes = @training_classes.where("date >= ?", Date.parse(params[:date_from]))
      end
      if params[:date_to].present?
        @training_classes = @training_classes.where("(end_date IS NOT NULL AND end_date <= ?) OR (end_date IS NULL AND date <= ?)", Date.parse(params[:date_to]), Date.parse(params[:date_to]))
      end
    end

    def training_class_params
      params.require(:training_class).permit(:title, :description, :date, :end_date, :start_time, :end_time, :location, :max_attendees, :instructor, :cost, :price, :vat_excluded)
    end
  end
end
