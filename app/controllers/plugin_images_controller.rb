class PluginImagesController < PluginController
  #skip_before_filter :find_record, :only => [:tinymce]

  def single_access_allowed?
    action_name == "create" 
  end  
  
  def new
    @image = PluginImage.new
  end

  def create
    @image = PluginImage.new(params[:plugin_image])
    @image.effects = params[:effects]
    @image.user = @logged_in_user
    @image.record = @record if defined?(@record)
    @image.is_approved = "1" if !@group_permissions_for_plugin.requires_approval?  || @item.is_editable_for_user?(@logged_in_user) # approve if not required or owner or admin
    
    if @image.save # if image was saved successfully
      flash[:success] =  t("notice.item_create_success", :item => PluginImage.model_name.human)
      flash[:success] +=  t("notice.item_needs_approval", :item => PluginImage.model_name.human) if !@image.is_approved?
      log(:log_type => "create", :target => @image)
      
      respond_to do |format|
        format.html{
          if params[:tinymce] == "true" # redirect them back to the tinymce popup box
            redirect_to :back      
          else # redirect them back to item page
            redirect_to :back, :anchor => @plugin.model_name.human(:count => :other) 
          end       
        }
        format.flash{ render :text => t("notice.item_create_success", :item => PluginImage.model_name.human + (!@image.filename.blank? ? ": #{@image.filename}" : "") ) }              
      end           
    else # save failed
      flash[:failure] =  t("notice.item_create_failure", :item => PluginImage.model_name.human)
      respond_to do |format|
        format.html{render :action => "new"}   
        format.flash{render :text =>  t("notice.item_create_failure", :item => PluginImage.model_name.human + (!@image.filename.blank? ? ": #{@image.filename}" : "") ) + "\n" + @image.errors.full_messages.join("\n")}
      end
    end    
  end 

  def delete
    @image = PluginImage.find(params[:image_id])
    if @image.destroy
      log(:log_type => "destroy", :target => @image)
      flash[:success] =  t("notice.item_delete_success", :item => PluginImage.model_name.human)     
    else # fail saved 
      flash[:failure] =  t("notice.item_delete_failure", :item => PluginImage.model_name.human)   
    end
    
    if params[:tinymce] == "true" # redirect them back to the tinymce popup box
      redirect_to :back, :anchor => @plugin.model_name.human(:count => :other) 
    else # redirect them back to item page
      redirect_to :back, :anchor => @plugin.model_name.human(:count => :other) 
    end
  end

  def edit
    @image = PluginImage.find(params[:image_id])    
  end
  
  def update
    @image = PluginImage.find(params[:image_id])
    if @image.update_attributes(params[:plugin_image])
       log(:log_type => "update", :target => @image)
       flash[:success] =  t("notice.item_save_success", :item => PluginImage.model_name.human)     
    else
      flash[:success] =  t("notice.item_save_failure", :item => PluginImage.model_name.human)     
    end 
    render :action => "edit"
  end

  def tinymce # show images to use with tinymce images
    @plugin_image = PluginImage.new
    if item_is_present
      @images = PluginImage.record(@record).paginate(:page => params[:page], :per_page => 25)
    else
      authenticate_admin
      @images = PluginImage.paginate(:page => params[:page], :per_page => 25)      
    end 
    render :layout => false 
  end
  
private  
end
