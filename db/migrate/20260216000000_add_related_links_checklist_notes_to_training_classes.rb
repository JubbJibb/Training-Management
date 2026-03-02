# frozen_string_literal: true

class AddRelatedLinksChecklistNotesToTrainingClasses < ActiveRecord::Migration[8.1]
  def change
    add_column :training_classes, :related_links, :text, default: "[]"
    add_column :training_classes, :checklist_items, :text, default: "[]"
    add_column :training_classes, :notes, :text, default: "[]"
  end
end
