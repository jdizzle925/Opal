class PluginReviewsController < ApplicationController
 # before_filter :authenticate_user # check if user is logged in and not a public user  
 before_filter :find_item # look up item 
 before_filter :find_plugin
 before_filter :get_plugin_settings
 before_filter :get_my_group_plugin_permissions # get permissions for this plugin  
 before_filter :check_item_edit_permissions, :only => [:change_approval] # list of actions that don't require that the item is editable by the user
 
 uses_tiny_mce :only => [:new, :edit]  # which actions to load tiny_mce, TinyMCE Config is done in Layout.

 include ActionView::Helpers::TextHelper # for truncate, etc.


 def get_plugin_settings # get settings just for this plugin
   @setting[:review_type] = @plugin.get_setting("review_type")
   @setting[:score_min] = @plugin.get_setting("score_min").to_i     
   @setting[:score_max] = @plugin.get_setting("score_max").to_i   
 end 
 
 def create
   
   if @my_group_plugin_permissions.can_create? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # check permissions                   
      @item = Item.find(params[:id])
      if @item.is_viewable_for_user?(@logged_in_user) && ((@plugin.get_setting_bool("only_creator_can_review") && @logged_in_user.id == @item.user_id) || !@plugin.get_setting_bool("only_creator_can_review") || @logged_in_user.is_admin?)
         @previous_reviews = PluginReview.find(:all, :conditions => ["user_id = ? and item_id = ?", @logged_in_user.id, @item.id])
         if @previous_reviews.size == 0 # they haven't added a review yet.
           @review = PluginReview.new
           @review.review_score = params[:review][:review_score]
           @review.review = sanitize(params[:review][:review])
           @review.user_id = @logged_in_user.id
           @review.item_id = @item.id
           @review.is_approved = "1" if !@my_group_plugin_permissions.requires_approval? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # approve if not required or owner or admin       
           if @review.review_score >=  @setting[:score_min] && @review.review_score <= @setting[:score_max] 
             if @review.save
              Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "new", :log => t("log.item_create", :item => @plugin.human_name,  :name => truncate(@review.review, :length => 10)))                                       
              flash[:success] = t("notice.item_create_sucess", :item => @plugin.human_name)
              flash[:success] += t("notice.user_thanks", :name => @review.user.first_name)
              redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
             else # fail saved 
              flash[:failure] = t("notice.item_create_failure", :item => @plugin.human_name)
              render :action => "edit"
             end
            else # score out of range
              render :action => "edit"
              #flash[:failure] = "#{@plugin.title} score must be between #{@setting[:score_min]} and #{@setting[:score_max]}"
            end          
         else # they've already added a review.
            render :action => "edit"
            #flash[:failure] = "Sorry, You've already left a review for this #{@setting[:item_name]}."
         end    
      else # they're not allowed to add the review
        flash[:failure] = t("notice.invalid_permissions")
        redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
      end
   else # Improper Permissions  
        flash[:failure] = t("notice.invalid_permissions")
        redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
   end       
 end
 
 def delete
   if @my_group_plugin_permissions.can_delete? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # check permissions               
     @review = PluginReview.find(params[:review_id])
     @review_user = User.find(@review.user_id)
     if @review.destroy
       Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "delete", :log => t("log.item_delete", :item => @plugin.human_name,  :name => truncate(@review.review, :length => 10)))                                       
       flash[:success] =  t("notice.item_delete_success", :item => @plugin.human_name)    
     else # fail saved 
       flash[:failure] =  t("notice.item_delete_failure", :item => @plugin.human_name)     
     end
   else # Improper Permissions  
        flash[:failure] = t("notice.invalid_permissions")            
   end  
   redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
 end

def update
  if @my_group_plugin_permissions.can_update? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # check permissions               
    @review = PluginReview.find(params[:review_id])
    @review_user = User.find(@review.user_id)
    @review.review_score = params[:review][:review_score]
    @review.review = sanitize(params[:review][:review])     
    if @review.review_score >=  @setting[:score_min] && @review.review_score <= @setting[:score_max]      
      if @review.save
        Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "update", :log => t("log.item_save", :item => @plugin.human_name,  :name => truncate(@review.review, :length => 10)))                                       
        flash[:success] =  t("notice.item_save_success", :item => @plugin.human_name)     
      else # fail saved 
        flash[:failure] =  t("notice.item_save_failure", :item => @plugin.human_name)     
      end       
    else # score out of range
      flash[:failure] = "#{@plugin.title} score must be between #{@setting[:score_min]} and #{@setting[:score_max]}"
    end 
    render :action => "edit"
  else # Improper Permissions  
    flash[:failure] = t("notice.invalid_permissions")
    redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
  end  
end
 
 
 def change_approval
    @review = PluginReview.find(params[:review_id])    
    if  @review.is_approved?
      approval = "0" # set to unapproved if approved already    
      log_msg = t("log.item_unapprove", :item => @plugin.human_name,  :name => "#{@review.user.username} - " + truncate(@review.review, :length => 10))
    else
      approval = "1" # set to approved if unapproved already    
      log_msg = t("log.item_approve", :item => @plugin.human_name,  :name => "#{@review.user.username} - " + truncate(@review.review, :length =>  10))
    end
    
    if @review.update_attribute(:is_approved, approval)
      Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "update", :log => log_msg)      
      flash[:success] = t("notice.item_approve_success", :item => @plugin.human_name) 
    else
      flash[:failure] =  t("notice.item_save_failure", :item => @plugin.human_name)
    end
    redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize 
  end 
  
  def new 
   if @my_group_plugin_permissions.can_create? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # check permissions
      @review = PluginReview.new     
   else # Improper Permissions  
        flash[:failure] = t("notice.invalid_permissions")    
        redirect_to :action => "view", :controller => "items", :id => @item.id     
   end    
  end
 
  def edit
     if @my_group_plugin_permissions.can_update? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin?
       @review = PluginReview.find(params[:review_id])
      
     else # Improper Permissions  
          flash[:failure] =  t("notice.invalid_permissions")
          redirect_to :action => "view", :controller => "items", :id => @item.id                 
     end    
 end 
 
 def vote
   if @my_group_plugin_permissions.can_create? || @item.is_user_owner?(@logged_in_user) || @logged_in_user.is_admin? # check permissions
      @review = PluginReview.find(params[:review_id])    
      @vote = PluginReviewVote.new(:plugin_review_id => @review.id, :user_id => @logged_in_user.id)
      if params[:direction] == "up"
        @vote.score = 1 # vote score 
        Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "update", :log => t("log.item_voted_for", :item => @plugin.human_name, :name => "#{@review.user.username} - " + truncate(@review.review, :length =>  10)))              
      elsif params[:direction] == "down"
        @vote.score = -1 # vote score 
        Log.create(:user_id => @logged_in_user.id, :item_id => @item.id,  :log_type => "update", :log => t("log.item_voted_against", :item => @plugin.human_name, :name => "#{@review.user.username} - " + truncate(@review.review, :length => 10)))      
      end
      if @vote.save && @review.update_attribute(:vote_score, @review.vote_score + @vote.score)  # save record of vote and increment/decrement review's score
        flash[:success] = t("notice.user_thanks_for_voting", :name => @vote.user.first_name)             
      else # save failed 
        flash[:failure] = t("notice.item_save_failure", :item => PluginReviewVote.human_name)
      end
   else # Improper Permissions  
      flash[:failure] = t("notice.invalid_permissions")         
  end
  redirect_to :action => "view", :controller => "items", :id => @item.id, :anchor => @plugin.human_name.pluralize               
 end                    

end
