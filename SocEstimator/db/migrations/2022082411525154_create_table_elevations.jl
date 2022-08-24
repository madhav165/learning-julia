module CreateTableElevations

import SearchLight.Migrations: create_table, column, columns, pk, add_index, drop_table, add_indices

function up()
  create_table(:elevations) do
    [
      pk()
      column(:distance, :float, limit=1000)
      column(:elevation, :float, limit=1000)
      # columns([
      #   :distance => :float, 
      # ])
    ]
  end

  add_index(:elevations, :distance)
  # add_indices(:elevations, :column_name_1, :column_name_2)
end

function down()
  drop_table(:elevations)
end

end
