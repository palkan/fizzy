class ReplaceHiddenFromViewersWithMinRole < ActiveRecord::Migration[8.2]
  def change
    add_column :columns, :min_role, :string, default: "viewer", null: false

    reversible do |dir|
      dir.up do
        execute "UPDATE columns SET min_role = 'member' WHERE hidden_from_viewers = TRUE"
      end
      dir.down do
        execute "UPDATE columns SET hidden_from_viewers = TRUE WHERE min_role != 'viewer'"
      end
    end

    remove_column :columns, :hidden_from_viewers, :boolean, default: false, null: false
  end
end
