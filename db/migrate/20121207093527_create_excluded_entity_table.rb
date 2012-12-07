class CreateExcludedEntityTable < ActiveRecord::Migration
  def change
    create_table :excluded_entities
  end
end
