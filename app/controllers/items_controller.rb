class ItemsController < ApplicationController
 before_filter :authenticate_user, :only => [:edit, :update, :delete, :create, :new, :my] 
 before_filter :enable_user_menu, :only =>  [:new, :edit, :create, :update, :my] # show user menu 
 
 before_filter :authenticate_admin, :only =>  [:all_items, :settings, :change_item_name, :do_change_item_name] # check if user is admin 
 before_filter :enable_admin_menu, :only =>  [:all_items, :settings, :change_item_name, :do_change_item_name] # show admin menu 
 
 before_filter :find_item, :only => [:view, :edit, :update, :delete, :set_preview] # look up item  
 before_filter(:only => [:view]) {|c| can?(@item, @logged_in_user, :view)} 
 before_filter(:only => [:edit, :update, :set_preview]) {|c| can?(@item, @logged_in_user, :edit)}  
 before_filter(:only => [:delete]) {|c| can?(@item, @logged_in_user, :destroy)}  
 before_filter :enable_sorting, :only => [:index, :category, :all_items, :search, :my] # prepare sort variables & defaults for sorting

  def index # show all items to user
    @setting[:homepage_type] = Setting.get_setting("homepage_type")    
    if @logged_in_user.is_admin?
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page].to_i, :order => Item.sort_order(params[:sort])     
    else      
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page].to_i, :order => Item.sort_order(params[:sort]), :conditions => ["is_approved = '1' and is_public = '1'"]
    end
    @setting[:meta_title] << Item.model_name.human(:count => :other) 
  end
 
  def category # get all items for a category and its children/descendants recursively
    @category = Category.find(params[:id]) 
    #@setting[:include_child_category_items] = Setting.get_setting_bool("include_child_category_items") # get a bool object for a setting to pass into various functions that use it(reduces redundant db queries).
    category_ids = @category.get_all_ids(:include_children => @setting[:include_child_category_items]).split(',') # get an array of category ids to be passed into Mysql IN clause
    current_page = params[:page] ||= 1 
    page = @setting[:items_per_page].to_i
    
    @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page].to_i, :order => Item.sort_order(params[:sort]), :conditions => ["category_id IN (?) and is_approved = '1' and is_public = '1'", category_ids]    
    
    @setting[:meta_title] << @category.name 
    @setting[:meta_description] << [@category.name , @category.description, Item.model_name.human(:count => :other), @setting[:meta_description]].join(" - ")
     
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :layout => false }
    end
  end
 
  def all_items # show all items in system 
    if params[:type] == "unapproved" # show unapproved items
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort]), :conditions => ["is_approved = '0'"]
    elsif params[:type] == "approved" # show only approved, public items
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort]), :conditions => ["is_public = '1' and is_approved = '1'" ]      
    elsif params[:type] == "private" # show only private items
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort]), :conditions => ["is_public = '0'" ]            
    else # show all items 
      params[:type] = t("single.all")
      @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort])
    end
  end 

  # Regular Methods   

  def view
      @setting[:meta_title] << @item.description unless @item.description.blank?    
      @setting[:meta_title] << @item.name unless @item.name.blank? 
      @setting[:meta_description] = @setting[:meta_title]
      @item.update_attribute(:views, @item.views += 1) # update total views
      @item.update_attribute(:recent_views, @item.recent_views += 1) # update recent views  
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :layout => false }
      end      
    rescue ActiveRecord::RecordNotFound # the item doesn't exist
        flash[:failure] = t("notice.item_not_found", :item => Item.model_name.human + " #{(@item.id)}")
        redirect_to :action => "index", :controller => "browse"
  end
 
  def new
    @item = Item.new
    params[:id] ||= Category.find(:first).id # set item's category the first category if not specified
    @item.category_id = params[:id] if params[:id]
    @item.is_approved = "1" if @logged_in_user.is_admin? # check the is_approved checkbox 
  end  

  def update
    # Handle Defaults & Unselected/Unchecked Options
    params[:item][:is_approved]   ||= "0" 
    params[:item][:is_public]     ||= "0" 
    params[:item][:featured]      ||= false
        
    @feature_errors = PluginFeature.check(:features => params[:features], :record => @item) # check if required features are present
    
    @item.attributes = params[:item] # mass assign any new attributes, but don't save.
    if @logged_in_user.is_admin? # save protected attributes
      @item.user_id = params[:item][:user_id] if !params[:item][:user_id].blank? 
      @item.is_approved = params[:item][:is_approved] if !params[:item][:is_approved].blank?
      @item.featured = params[:item][:featured] if !params[:item][:featured].blank?
    end 
    
    if @item.save && @feature_errors.size == 0 # make sure there's not required feature errors        
        # Update Features
        num_of_features_updated = PluginFeature.create_values_for_record(:record => @item, :features => params[:features], :user => @logged_in_user, :delete_existing => true, :approve => true)  
        log(:log_type => "update", :target => @item)
        flash[:success] = t("notice.item_save_success", :item => Item.model_name.human)
        redirect_to :action => "view" , :id => @item        
    else # failed adding required features
      flash[:failure] = t("notice.item_save_failure", :item => Item.model_name.human)
      render :action => "edit"
    end    
    
  end

  def create    
    @item = Item.new(params[:item])
    @item.user_id = @logged_in_user.is_admin? && !params[:item][:user_id].blank? ? params[:item][:user_id] : @logged_in_user.id
    @item.locked = params[:item][:locked] if @logged_in_user.is_admin? && !params[:item][:locked].blank?
    @item.featured = params[:item][:featured] if @logged_in_user.is_admin? && !params[:item][:featured].blank?
        
    @item.is_public = "0" if (!params[:item][:is_public] && (get_setting_bool("allow_private_items") || @logged_in_user.is_admin?))  # make private if is_public checkbox not checked
    if (@logged_in_user.is_admin? && params[:item][:is_approved]) || (!@logged_in_user.is_admin? && !get_setting_bool("item_approval_required"))   
      @item.is_approved = "1" # make approved if admin or if item approval isn't required
    else # this item is unapproved
       flash[:notice] = t("notice.item_needs_approval", :item => Item.model_name.human)    
    end 

    params[:item][:category_id] ||= Category.find(:first).id # assign the first category's id if not selected.
    @feature_errors = PluginFeature.check(:features => params[:features], :item => @item) # check if required features are present        
    if @item.save && @feature_errors.size == 0 # item creation failed
      log(:log_type => "create", :target => @item)
      # Create Features
      num_of_features_updated = PluginFeature.create_values_for_record(:record => @item, :features => params[:features], :user => @logged_in_user, :delete_existing => true, :approve => true)
      flash[:success] = t("notice.item_create_success", :item => Item.model_name.human)
      redirect_to :action => "view", :controller => "items", :id => @item
    else
      flash[:failure] = t("notice.item_create_failure", :item => Item.model_name.human)
      render :action => "new"
    end     
  end
  
  def delete
   log(:log_type => "destroy", :target => @item) if @item.destroy
   flash[:success] = t("notice.item_delete_success", :item => Item.model_name.human)
   redirect_to :action => "my"
  end

 def rss
   @latest_items = Item.find(:all, :conditions => ["is_approved = '1' and is_public = '1'"], :limit => 10, :order => "created_at DESC")
   render :layout => false
 end

 def search
   if !params[:search_for] == "" || !params[:search_for].nil?
    @search_for = params[:search_for] # what to search for
    @setting[:meta_title] << t("label.search_results_for", :query => @search_for) 
    @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page], :order => Item.sort_order(params[:sort]), :conditions => ["name like ? or description like ? and is_approved = '1' and is_public = '1'", "%#{@search_for}%", "%#{@search_for}%" ]
   else # No Input
     flash[:failure] = t("notice.search_results_left_blank")
     redirect_to :action => "index"
   end
 end
 
 def new_advanced_search
   #@setting[:load_prototype] = true # use prototype for ajax calls in this method, instead of jquery
 end


 def advanced_search
   @options = Hash.new
   @options[:item_ids] = Array.new # Array to hold item ids to search
   conditions = Array.new # holds search conditions
   
   # Santize User Input
      # todo
  
   # Prepare Features
   if params[:feature] # if there are any feature fields submitted
     # We need to sanitize all values entering the ActiveRecord's conditions. They will be passed in via the array[string, hash] format: ActiveRecord::Base.find(:all, :conditions => ["x = :x_value", {:x_value => "someValue"}])
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
      
    @options[:item_ids] =  get_common_elements_for_hash_of_arrays(matching_feature_values) if num_of_features_to_search > 0 # get common elements from hash using & operator    
    #logger.info "Matching Items: #{matching_feature_values.inspect}"
  else # no features selected
  end 
         


   # Prepare Category
     @options[:category_ids] = Array.new # Array to hold category ids to search 
     params[:item][:category_id] = params[:item][:category_id].to_i
     category = Category.find(params[:item][:category_id]) if params[:item][:category_id] > 0

   
   # Prepare Times
     times  = Hash.new # create a new hash indexed by html value, which contains a time object to be passed into query 
     times["whenever"] = Time.now.to_time.advance(:years => -100).to_sql
     times["today"] = Time.now.beginning_of_day.to_sql
     times["this_week"] = Time.now.beginning_of_week.to_sql
     times["this_month"] = Time.now.beginning_of_month.to_sql
     times["this_year"] = Time.now.beginning_of_year.to_sql
  
     conditions << ["(created_at >= ? and updated_at >= ?)", times[params[:created_at]], times[params[:created_at]]]  # select hash item that matches selected form data

     # Prepare Name/Description     
     conditions << ["(name like ? or description like ?)", "%#{params[:search]["keywords"]}%", "%#{params[:search]["keywords"]}%"] if params[:search]["keywords"] && !params[:search]["keywords"].empty?
     
     # Prepare Item Ids
     conditions << ["id in (?)", @options[:item_ids].join(",")] if @options[:item_ids].size > 0 

    # Get Item That match our Search
    @items = Item.find(:all, :conditions => ActiveRecord::Base.combine_conditions(conditions), :limit => 20)
    respond_to do |format|
      format.html do
        if request.xhr?
          render :layout => false
        else
          # render regular action
        end
      end
    end  
 end 
 
 def tag
   @tag = CGI::unescape(params[:tag])   
   @category = Category.find(params[:category_id]) if params[:category_id]
   tags = @category ? PluginTag.category(@category).where(:name => @tag, :record_type => "Item") : PluginTag.where(:name => @tag, :record_type => "Item") 
   @items = Array.new # create container to hold items
   for tag in tags
     temp_item = tag.record # get the item that the tag points to
     @items << temp_item # Throw item into array     
   end
 end
 
 def set_list_type # change the item list type 
   if get_setting_bool("allow_item_list_type_changes")   
     session[:list_type] = params[:list_type] # save the list type in the visitor's browser sessions
   else # not allowed to change list type
     flash[:failure] = t("notice.invalid_permissions")
   end 
   redirect_to !params[:redirect_to].blank? ? CGI::unescape(params[:redirect_to]) : {:action => "index", :controller => "items"}  # send them back to original request 
 end

 def set_item_page_type # change the item list type 
   if get_setting_bool("allow_item_page_type_changes")   
     session[:item_page_type] = params[:item_page_type] # save the list type in the visitor's browser sessions
   else # not allowed to change list type
     flash[:failure] = t("notice.invalid_permissions")
   end 
   redirect_to !params[:redirect_to].blank? ? CGI::unescape(params[:redirect_to]) : {:action => "index", :controller => "items"}  # send them back to original request 
 end
 
 def change_item_name
   @item_pluralization_cases = I18n.t("activerecord.models.item")
 end
 
 def do_change_item_name # rewrite translation file with custom item name & pluralization case
   $KCODE = 'UTF8' unless RUBY_VERSION >= '1.9' # for ya2yaml

   # Load & Modify Locale Hash
   current_locale_hash = YAML::load(File.open(Opal.current_locale_path)) # get full locale hash
   if current_locale_hash[I18n.locale.to_s]["activerecord"]["models"]["item"]      
     # Write Changes to Separate File
     item_name_file = File.join(Rails.root.to_s, "config", "locales", "item.yml")
     item_name_hash = {I18n.locale.to_s => {"activerecord" => {"models" => {"item" => utf8_hash(params[:key].to_hash)}}}} # to_hash converts ActiveSupport::HashWithIndifferentAccess to regular hash for proper yaml conversion          
     File.open(item_name_file, "w") { |f| f.write item_name_hash.ya2yaml } # you can also use ya2yaml instead of to_yaml, which hates utf-8
     
     log(:log_type => "system", :log => t("log.item_save", :item => Item.model_name.human + " " + t("single.name"), :name => params[:key].values.join(", ")))       
     flash[:success] = t("notice.save_success")
     I18n.load_path.push(item_name_file) # add item_name_file onto load_path 
     I18n.reload! # reload I18n to see our new changes
   else
     flash[:success] = t("notice.item_not_found", :item => "#{I18n.locale.to_s}.activerecord.models.item")
   end 
   redirect_to :action => "change_item_name"
 end
 
  def my # get items for logged in user
    @items = Item.paginate :page => params[:page], :per_page => @setting[:items_per_page].to_i, :order => Item.sort_order(params[:sort]) , :conditions => ["user_id = ?", @logged_in_user.id]
    @plugins = Plugin.enabled 
  end  
 
  def set_preview
    if @item.update_attributes(:preview_type => params[:preview_type], :preview_id => params[:preview_id])
      flash[:success] = t("notice.save_success")
    else
      flash[:failure] = t("notice.save_failure")
    end  
    redirect_to :action => "view", :id => @item 
  end
  
private 
  def utf8_hash(some_hash) # convert hash key & values to utf-8 for proper translation
    if RUBY_VERSION < "1.9" # are they using an old version of Ruby? 
      some_hash
    else
      new_hash = Hash.new
      some_hash.each do |key, value|
        new_hash[key.to_s.encode(::Encoding::UTF_8)] = value.to_s.encode(::Encoding::UTF_8) 
      end   
      new_hash  
    end
  end
 
  def get_common_elements_for_hash_of_arrays(hash) # get an array of common elements contained in a hash of arrays, for every array in the hash.
    #hash = {:item_0 => [1,2,3], :item_1 => [2,4,5], :item_2 => [2,5,6] } # for testing
    return hash.values.inject{|acc,elem| acc & elem} # inject & operator into hash values.
  end
  
end
