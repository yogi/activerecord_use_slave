class CreateMessageTableForTests < ActiveRecord::Migration
  def change
    create_table :messages
  end
end
