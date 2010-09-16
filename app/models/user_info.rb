class UserInfo < ActiveRecord::Base
 validates_uniqueness_of :user_id, :message => "There can only be one group of info per user!"
 belongs_to :user
 before_save :strip_html 
  
 def strip_html # Automatically strips any tags from any string to text typed column
    for column in UserInfo.content_columns
      if column.type == :string || column.type == :text # if the column is a sql string or text
        self[column.name] = self[column.name].gsub(/<\/?[^>]*>/, "")  if !self[column.name].nil? # strip html from string
      end
    end
 end
 
 def self.generate_forgot_password_code # generate code
   o = [('a'..'z'),('A'..'Z'),(0..9)].map{|i| i.to_a}.flatten;  
   return (0..50).map{ o[rand(o.length)]  }.join;
 end 
end