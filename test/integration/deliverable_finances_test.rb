require 'test_helper'

class DeliverableFinancesShowTest < ActionController::IntegrationTest
  include Redmine::I18n
  
  def setup
    configure_overhead_plugin
    @project = Project.generate!(:identifier => 'main').reload
    @contract = Contract.generate!(:project => @project, :billable_rate => 10)
    @manager = User.generate!
    @deliverable1 = RetainerDeliverable.spawn(:contract => @contract, :manager => @manager, :title => "Retainer Title", :start_date => '2010-01-01', :end_date => '2010-03-31')
    @deliverable1.labor_budgets << LaborBudget.spawn(:budget => 100, :hours => 10)
    @deliverable1.overhead_budgets << OverheadBudget.spawn(:budget => 200, :hours => 10)

    @deliverable1.save!
    @user = User.generate_user_with_permission_to_manage_budget(:project => @project)
    # 2 hours of $100 billable work
    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 2,
                                       :user => @manager)
    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)
    @deliverable1.issues << @issue1

    @user.reload
    login_as(@user.login, 'contracts')
  end

  context "for an anonymous request" do
    should "require login" do
      logout

      visit "/projects/#{@project.id}/contracts/#{@contract.id}/deliverables/#{@deliverable1.id}/finances"

      assert_response :success
      assert_template 'account/login'
    end

  end

  context "for an unauthorized request" do
    should "be forbidden" do
      logout

      @user = User.generate!(:password => 'test', :password_confirmation => 'test')
      login_as(@user.login, 'test')

      visit "/projects/#{@project.id}/contracts/#{@contract.id}/deliverables/#{@deliverable1.id}/finances"

      assert_response :forbidden
    end

  end


  context "for an authorized request" do
    should "render the finance report title section for the deliverable" do
      visit "/projects/#{@project.id}/contracts/#{@contract.id}/deliverables/#{@deliverable1.id}/finances"

      assert_response :success
      assert_select "h2", :text => /#{@deliverable1.title}/

      assert_select "div#summary" do
        assert_select "span.spent", :text => /\$200/ # $100 * 2
        assert_select "span.total", :text => /\$300/ # $100 * 3
        assert_select "span.hours", :text => /2/
      end
    end

  end
end