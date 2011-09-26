require 'spec_helper'

describe PluginVideosController do  
  render_views
  
  describe "as admin" do
    before(:each) do
      login_admin
    end 
  end
  
  context "as user" do
    before(:each) do
      login_user
      @item = Factory(:item, :user => @controller.set_user)
    end 
        
    describe "new" do
      it "should return 200" do         
        get :new, {:id =>  @item.id}
        @response.code.should eq("200")
      end
    end

    describe "edit" do
      it "should return 200" do
        @video = Factory(:plugin_video, :record => @item)
        get :edit, {:id =>  @video.record.id, :video_id => @video.id}
        @response.code.should eq("200")
        @video.destroy # clean up
      end
    end  
    
    describe "create" do 
      it "should create video with embedded code" do
        expect{
          post(:create, {:id => @item.id, :plugin_video => Factory.attributes_for(:plugin_video)})
        }.to change(PluginVideo, :count).by(+1)
        flash[:success].should_not be_nil
        assigns[:video].destroy # clean up
      end 

      it "should create video with uplpoaded file" do
        expect{
          post(:create, {:id => @item.id, :plugin_video => Factory.attributes_for(:uploaded_plugin_video)})
        }.to change(PluginVideo, :count).by(+1)
        flash[:success].should_not be_nil
        assigns[:video].destroy # clean up
      end     
    end
    
    describe "destroy" do 
      it "should reduce count and return success" do
      @video = Factory(:plugin_video, :record => @item)
        expect{
          post(:delete, {:id => @item.id, :video_id => @video.id})
        }.to change(PluginVideo, :count).by(-1) 
        flash[:success].should_not be_nil
      end 
    end
  end
end
