class <%= new_class_name %> < ActiveRecord::Base

  hobo_model # Don't put anything above this

  fields do
<% for column, length in data_lengths -%>
    <%= column %> :string, :length => <%= length %>
<% end -%>
    imported_from_file :text
    line_number :integer
    timestamps
  end


  # --- Permissions --- #

  def create_permitted?
    acting_user.administrator?
  end

  def update_permitted?
    acting_user.administrator?
  end

  def destroy_permitted?
    acting_user.administrator?
  end

  def view_permitted?(field)
    true
  end

end
