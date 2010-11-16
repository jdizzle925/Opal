class CategoriesController < ApplicationController
  before_filter :authenticate_admin # make sure logged in user is an admin   
  before_filter :enable_admin_menu
  
  def index 
    @setting[:meta_title] = @setting[:meta_title] = Category.human_name.pluralize + " - " + t("section.title.admin").capitalize + " - " + @setting[:meta_title]
    @categories = Category.find(:all, :conditions =>["category_id = 0"], :order => "name ASC")
  end
  
  def edit
   if params[:id] 
     @category = Category.find(params[:id])
   end     
  end
  
  def new 
   @category = Category.new
   if params[:id] 
     @category.category_id = Category.find(params[:id]).id
   end   
  end
  
  def update
    category = Category.find(params[:id])    
    if params[:category][:category_id].to_i != category.id # trying to select self as parent category 
      if category.update_attributes(params[:category])
        Log.create(:user_id => @logged_in_user.id,  :log_type => "system", :log => t("log.item_save", :item => Category.human_name, :name => category.name))
        flash[:success] = t("notice.save_success")
      else
        flash[:failure] = t("notice.save_failure")
      end
    else
      flash[:failure] = t("notice.association_loop_failure", :item => Category.human_name)
    end      
    redirect_to :action => "index"
  end
  
  def create # creates a new Feature, not a Feature Value
    #category = Category.find(params[:id])   
    category = Category.new(params[:category])
    
    if category.save
      Log.create(:user_id => @logged_in_user.id, :log_type => "system", :log => t("log.item_create", :item => Category.human_name, :name => category.name))
      flash[:success] = t("notice.item_create_success", :item => Category.human_name)
     else
      flash[:failure] = t("notice.item_create_failure", :item => Category.human_name)
       category.errors.each do |key,value|
        flash[:notice] << "<b>#{key}</b>...#{value}</font><br>" #print out any errors!
       end
      flash[:notice] << ""
      
      
    end
    redirect_to :action => "index"
  end
 
  def delete # deletes feature 
    category = Category.find(params[:id])    
    if category.destroy
      Log.create(:user_id => @logged_in_user.id,  :log_type => "system", :log =>  t("log.item_delete", :item => Category.human_name, :name => category.name))
      flash[:success] = t("notice.item_delete_success", :item => Category.human_name)
     else
      flash[:failure] = t("notice.item_delete_failure", :item => Category.human_name)
    end
    redirect_to :action => "index"
  end

end
