class ItemsController < ApplicationController
 before_filter :authenticate_user, :except => [:index, :category, :view, :search, :tag, :new_advanced_search, :advanced_search] # check if user is logged in
 before_filter :enable_user_menu, :only =>  [:new, :edit] # show admin menu 
 
 before_filter :authenticate_admin, :only =>  [:all_items] # check if user is admin 
 before_filter :enable_admin_menu, :only =>  [:all_items] # show admin menu 
 
 before_filter :find_item, :except => [:index, :category, :all_items, :tag, :create, :new, :search, :new_advanced_search, :advanced_search] # look up item 
 before_filter :check_item_edit_permissions, :except => [:index, :category, :all_items, :tag, :create, :view, :new, :search, :new_advanced_search, :advanced_search] # check if item is editable by user 
 before_filter :enable_sorting, :only => [:index, :category, :all_items, :search] # prepare sort variables & defaults for sorting
 
  # Filter Methods

  def find_plugin(plugin_name) # find @plugin and check to see if @plugin is activated
    @plugin = Plugin.find(:first, :conditions => ["name = ?", plugin_name])
    if @plugin.is_enabled?
        # proceed
    else # not enabled
      flash[:notice] = "<div class=\"flash_failure\">Sorry, #{@plugin.title}s aren't enabled.</div><br>"
      redirect_to :action => "index", :controller => "user"
    end 
  end  
 
  def index # show all items to user
   @setting[:homepage_type] = Setting.get_setting("homepage_type")    
   if @logged_in_user.is_admin?
    @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page].to_i, :order => Item.sort_order(params[:sort])     
   else      
    @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page].to_i, :order => Item.sort_order(params[:sort]), :conditions => ["is_approved = '1' and is_public = '1'"]
   end 
  end
 
  def category # get all items for a category and its children/descendants recursively
     @category = Category.find(params[:id]) 
     #@setting[:include_child_category_items] = Setting.get_setting_bool("include_child_category_items") # get a bool object for a setting to pass into various functions that use it(reduces redundant db queries).
     category_ids = @category.get_all_ids(:include_children => @setting[:include_child_category_items]).split(',') # get an array of category ids to be passed into Mysql IN clause
     current_page = params[:page] ||= 1 
     page = @setting[:items_per_page].to_i
     
     @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page].to_i, :order => "created_at DESC", :conditions => ["category_id IN (?) and is_approved = '1' and is_public = '1'", category_ids]    
     
     @setting[:meta_title] = @category.name + " - " + @setting[:meta_title]
     @setting[:meta_keywords] = @category.name + " - " + @category.description + " - " + @setting[:item_name_plural] + " - " + @setting[:meta_keywords]
     @setting[:meta_description] = @category.name + " - " + @category.description + " - " + @setting[:item_name_plural] + " - " + @setting[:meta_description]   
  end
 
  def all_items # show all items in system 
    if params[:type] == "unapproved" # show unapproved items
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort]), :conditions => ["is_approved = '0'"]
    elsif params[:type] == "approved" # show only approved, public items
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort]), :conditions => ["is_public = '1' and is_approved = '1'" ]      
    elsif params[:type] == "private" # show only private items
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort]), :conditions => ["is_public = '0'" ]            
    else # show all items 
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort])
    end
  end 

  # Regular Methods   

  def view
    @item = Item.find(params[:id])
    if @item.is_viewable_for_user?(@logged_in_user) 
      @setting[:meta_title] = @item.name + " - " + @item.description + " - " + @item.category.name + " " + @setting[:item_name_plural] + " - " + @setting[:meta_title]
      @setting[:meta_keywords] = @item.name + " - " + @item.description + " - "+ @item.category.name + " " + @setting[:item_name_plural] + " - " + @setting[:meta_keywords]
      @setting[:meta_description] = @item.name + " - " + @item.description + " - "+ @item.category.name + " " + @setting[:item_name_plural] + " - " + @setting[:meta_description]
      @item.update_attribute(:views, @item.views += 1) # update total views
      @item.update_attribute(:recent_views, @item.recent_views += 1) # update recent views  
    else # the user can't see this item for some reason.
        flash[:notice] = "<div class=\"flash_failure\">Sorry, you're not allowed to see this item.</div><br>"
        redirect_to :action => "index", :controller => "browse"
    end
    rescue ActiveRecord::RecordNotFound # the item doesn't exist
        flash[:notice] = "<div class=\"flash_failure\">Sorry, no #{@setting[:item_name]} found with the id: <b>#{params[:id]}</b>.</div><br>"
        redirect_to :action => "index", :controller => "browse"
  end
 
  def new
    @item = Item.new
    params[:id] ||= Category.find(:first).id # set item's category the first category if not specified
    @item.category_id = params[:id] if params[:id]
    @item.is_approved = "1" if @logged_in_user.is_admin? # check the is_approved checkbox 
    if !get_setting_bool("let_users_create_items") && !@logged_in_user.is_admin? # users can't create items and they user isn't an admin
      flash[:notice] = "<div class=\"flash_failure\">Sorry, you're not allowed to add any more #{@setting[:item_name_plural]}.</div>"      
      redirect_to :action => "index"
    end
  end  


  def update
    # Handle Defaults & Unselected/Unchecked Options
    params[:item][:is_approved]   ||= "0" 
    params[:item][:is_public]     ||= "0" 
    params[:item][:featured]      ||= false
        
    feature_errors = PluginFeature.check(:features => params[:features], :item => @item) # check if required features are present
        
    if feature_errors.size == 0 # make sure there's not required feature errors
      if @item.update_attributes(params[:item])      
        # Update Protected Attributes 
        if @logged_in_user.is_admin? 
          @item.update_attribute(:is_approved, params[:item][:is_approved])
          @item.update_attribute(:featured, params[:item][:featured])        
        end
        
        # Update Features
        num_of_features_updated = PluginFeature.create_values_for_item(:item => @item, :features => params[:features], :user => @logged_in_user, :delete_existing => true, :approve => true)  
        Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "update", :log => "Updated #{@item.name}.")                    
        flash[:notice] = "<div class=\"flash_success\">This #{@setting[:item_name]} has been saved.</div>"                
      else #
        flash[:notice] = "<div class=\"flash_failure\">This #{@setting[:item_name]} could not be saved! Here's why: <br>#{print_errors(@item)}</div>"          
      end
    else # failed adding required features
      flash[:notice] = "<div class=\"flash_failure\">This #{@setting[:item_name]} could not be saved! Here's why: <br>#{print_errors(feature_errors)}</div>"          
    end    
    redirect_to :action => "edit" , :id => @item
    
  end

  def create
    flash[:notice] = "" 
    proceed = false # set default flag to false
    max_items = get_setting("max_items_per_user").to_i # get the amount
    if (max_items.to_i == 0 && get_setting_bool("let_users_create_items")) || @logged_in_user.is_admin? # users can add unlimited items or user is an admin
        # do nothing, proceed 
        proceed = true
    else # users can only add a limited number of items
      if get_setting("let_users_create_items") # are users allowed to create items? 
        users_items = Item.count(:all, :conditions => ["user_id = ?", @logged_in_user.id])
        if users_items < max_items # they can add more
          # do nothing, proceed 
        else # they can't add any more items
          flash[:notice] += "<div class=\"flash_failure\">You've already created the maximum number of #{@setting[:item_name_plural]}!</div>"
          proceed = false
        end
      end
    end
    
    @item = Item.new(params[:item])
    @item.user_id = @logged_in_user.id
    
    @item.is_public = "0" if (!params[:item][:is_public] && (get_setting_bool("allow_private_items") || @logged_in_user.is_admin?))  # make private if is_public checkbox not checked
    if (@logged_in_user.is_admin? && params[:item][:is_approved]) || (!@logged_in_user.is_admin? && !get_setting_bool("item_approval_required"))   
      @item.is_approved = "1" # make approved if admin or if item approval isn't required
    else # this item is unapproved
       flash[:notice] += "<div class=\"flash_success\">Your #{@setting[:item_name]} will need to be approved before it can be seen by others.</div>"    
    end 

   params[:item][:category_id] ||= Category.find(:first).id # assign the first category's id if not selected.

   if proceed  
    feature_errors = PluginFeature.check(:features => params[:features], :item => @item) # check if required features are present        
    if feature_errors.size == 0 # make sure there's not required feature errors
       if @item.save
         Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "new", :log => "Created #{@item.name}.")
  
         # Create Features
         num_of_features_updated = PluginFeature.create_values_for_item(:item => @item, :features => params[:features], :user => @logged_in_user, :delete_existing => true, :approve => true)
   
         Emailer.deliver_new_item_notification(@item, url_for(:action => "view", :controller => "items", :id => @item.id)) if Setting.get_setting_bool("new_item_notification")
         flash[:notice] += "<div class=\"flash_success\">Your #{@setting[:item_name]}, <b>#{@item.name}</b>, has been created! The next step is to add stuff to it! </div>"
         redirect_to :action => "view", :controller => "items", :id => @item
       else
          flash[:notice] += "<div class=\"flash_failure\">Your #{@setting[:item_name]} couldn't be created!<br>Here's why:<br>#{print_errors(@item)}</div>"
          redirect_to :action => "new", :controller => "items", :id => @item.category_id 
       end
    else # failed adding required features
      flash[:notice] = "<div class=\"flash_failure\">This #{@setting[:item_name]} could not be saved! Here's why: <br>#{print_errors(feature_errors)}</div>"
      redirect_to :action => "new", :controller => "items", :id => @item.category_id      
    end       
   else # they aren't allowed to add this
      flash[:notice] += "<div class=\"flash_failure\">Sorry, you're not allowed to add any more #{@setting[:item_name_plural]}.</div>"
      redirect_to :action => "new", :controller => "items", :id => @item.category_id
   end 
  end
  
  def delete
   @item = Item.find(params[:id])
   if @item.is_deletable_for_user?(@logged_in_user)
     Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "delete", :log => "Deleted #{@item.name}(#{@item.id}).")      
     @item.destroy
     flash[:notice] = "<div class=\"flash_success\">#{@setting[:item_name]} deleted!</div>"
   else # The user can't delete this item
     flash[:notice] = "<div class=\"flash_failure\">You're not allowed to delete this #{@setting[:item_name]}!</div>"
   end 
   redirect_to :action => "items", :controller => "/user"
  end


 def search
   if !params[:search_for] == "" || !params[:search_for].nil?
    @search_for = params[:search_for] # what to search for
    @setting[:meta_title] = "Search results for #{@search_for} - " + @setting[:meta_title] 
    @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort]), :conditions => ["name like ? or description like ? and is_approved = '1' and is_public = '1'", "%#{@search_for}%", "%#{@search_for}%" ]
   else # No Input
     flash[:notice] = "<div class=\"flash_failure\">I don't know what to search for!<br>"
     redirect_to :action => "index"
   end
 end
 
 def new_advanced_search
   @setting[:load_prototype] = true # use prototype for ajax calls in this method, instead of jquery
 end
 
 def advanced_search
   @options = Hash.new
   @options[:item_ids] = Array.new # Array to hold item ids to search
   
   # Prepare Features
     if params[:feature] # if there are any feature fields submitted
       # We need to sanitize all values entering the ActiveRecord's conditions. They will be passed in via the array[string, hash] format: ActiveRecord::Base.find(:all, :conditions => ["x = :x_value", {:x_value => "someValue"}])
       conditions_array = Array.new # hash to contain strings of certain conditions, ie: ["x = :x_value", "y LIKE :y_value"], which we will then join with the appropriate conjunction, ie: conditions.join(" AND ")  to create the required string
       values_hash = Hash.new # hash to contain values, ie: {:x_value => "someValue", :y_value => "%someValue%"}   
       num_of_features_to_search = 0 # number of features to search       
       matching_feature_values = Hash.new # hash to hold arrays of ids of items that match each feature value
       
       params[:feature].each do |feature_id, feature_hash|# loop through for every feature value, create a conditions
          #logger.info "#{feature_id} - #{feature_hash.inspect}"

         if feature_hash["search"] == "1" # was this feature's checkbox checked?
           num_of_features_to_search += 1 # increment number of features to search  
           
           # Determine Mysql Where Opertor by Feature Search Type
           matching_feature_values[feature_id] = Array.new # create array to hold matching item ids          
           if feature_hash["type"] == "Keyword" # if searching by Keyword
             matching_values = PluginFeatureValue.find(:all, :group => "item_id", :select => "item_id", :conditions => ["value like ?", "%#{feature_hash["value"]}%"]) # get items matching this feature                  
           else # some other search type
            matching_values = PluginFeatureValue.find(:all, :group => "item_id", :select => "item_id", :conditions => ["value = ?", "#{feature_hash["value"]}"]) # get items matching this feature                              
          end
          
          # Load Item IDs from matching values into arrays
          for value in matching_values 
            matching_feature_values[feature_id] << value.item_id 
          end
        end         
       end
     end    
       
     if num_of_features_to_search > 0 # were any features selected?
       #logger.info "Matching Items: #{matching_feature_values.inspect}"
       @options[:item_ids] =  get_common_elements_for_hash_of_arrays(matching_feature_values) # get common elements from hash using & operator
     else # no features selected, search all items
       Item.find(:all, :select => "id").each{|item|  @options[:item_ids] << item.id } # load all item ids into array
     end 

   # Prepare Category
     @options[:category_ids] = Array.new # Array to hold category ids to search 
     if params[:item][:category_id] == "all" # search all categories
       for category in Category.get_parent_categories 
          @options[:category_ids] +=  category.get_all_ids(:include_children => true).split(',')
       end
     else # search one category
       category = Category.find(params[:item][:category_id])
       @options[:category_ids] +=  category.get_all_ids(:include_children => @setting[:include_child_category_items]).split(',')
     end 
   
   # Prepare Times
     times  = Hash.new # create a new hash indexed by html value, which contains a time object to be passed into query 
     times["whenever"] = Time.now.to_time.advance(:years => -100) 
     times["today"] = Time.now.beginning_of_day
     times["this_week"] = Time.now.beginning_of_week
     times["this_month"] = Time.now.beginning_of_month
     times["this_year"] = Time.now.beginning_of_year
  
     @options[:created_at_start] = times[params[:created_at]] # select hash item that matches selected form data
     @options[:updated_at_start] = times[params[:updated_at]] # select hash item that matches form data

   # Get Item That match our Search
    @items = Item.find(:all, :conditions => ["(name like ? or description like ?) and id in (?) and category_id in (?) and ( created_at > ? and updated_at > ?)", "%#{params[:search]["keywords"]}%", "%#{params[:search]["keywords"]}%",  @options[:item_ids], @options[:category_ids], @options[:created_at_start], @options[:updated_at_start]  ], :limit => 20)
 
    render :layout => false # ajax powered? then no layout! 
 end
 
 def tag
   @tag = CGI::unescape(params[:tag])
   tags = PluginTag.find(:all, :conditions => ["name = ?", @tag])
   @items = Array.new # create container to hold items
   for tag in tags
     temp_item = Item.find(tag.item_id) # get the item that the tag points to
     @items << temp_item # Throw item into array     
   end
 end
 
private 

  def get_common_elements_for_hash_of_arrays(hash) # get an array of common elements contained in a hash of arrays, for every array in the hash.
    #hash = {:item_0 => [1,2,3], :item_1 => [2,4,5], :item_2 => [2,5,6] } # for testing
    return hash.values.inject{|acc,elem| acc & elem} # inject & operator into hash values.
  end
  
end
