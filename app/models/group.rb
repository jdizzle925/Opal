class Group < ActiveRecord::Base
  has_many :users
  has_many :group_plugin_permissions
  
  validates_uniqueness_of :name
  validates_presence_of :name
  
  after_destroy :destroy_everything
  
  attr_protected :is_deletable 
  
  default_scope :order => "name ASC"
  
  def destroy_everything
    for item in self.users # delete users
      item.destroy
    end    
    
    for item in self.group_plugin_permissions
      item.destroy
    end   
  end
  
  def is_admin_group? # if this the admins group 
    if self.id == 3
      return true
    else 
      return false
    end         
  end
  
  def is_deletable? # can this group be deleted
    if self.is_deletable == "1"
      return true
    else 
      return false
    end    
  end  
  
  
   def has_plugin_permission?(options = {}) # check if Group can access a particular permission/area a certain way(permission_type - CRUD Based)
    # set defaults 
    options ||= Hash.new 
    options[:plugin]                     ||= nil   # the plugin that is being accessed
    options[:permission_type]            ||= nil   # the type of action being performed
    options[:existing_plugin_permission] ||= nil   # initialize this if you want to use a preexisting Permission record, instead of looking up from db(reduces db strain)    
    
    if self.is_admin_group? # if Admins, access anything
      return true 
    else # not Admins
       if options[:existing_plugin_permission] # if plugin permission record is passed in(to prevent db strain)
         group_plugin_permission = options[:existing_plugin_permission]
       else # no local plugin permission record found, look up from db
         group_plugin_permission = GroupPluginPermission.find(:first, :conditions => ["plugin_id = ? and group_id = ?", options[:plugin].id, self.id])
       end
       if  group_plugin_permission # is there a GroupPermission for my group and this permission?
         if options[:permission_type] == :create # check if they can create
           return group_plugin_permission.can_create?
         elsif options[:permission_type] == :read # check if they can read
           return group_plugin_permission.can_read?
         elsif options[:permission_type] == :update # check if they can update
           return group_plugin_permission.can_update?
         elsif options[:permission_type] == :delete # check if they can delete
           return group_plugin_permission.can_delete?       
         elsif options[:permission_type] == :requires_approval # check approval is required for these permissions
           return group_plugin_permission.requires_approval?                
         else # some other permission_type
           return false 
         end
       else # no Record found
         return false
       end
    end
   end
end
