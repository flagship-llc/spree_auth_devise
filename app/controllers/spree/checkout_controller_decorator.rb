require_dependency 'spree/checkout_controller'
Spree::CheckoutController.class_eval do
  before_filter :check_authorization
  before_filter :check_registration, :except => [:registration, :update_registration]

  helper 'spree/users'

  def registration
    @user = Spree::User.new
  end

  def update_registration
    # hack - bypass this stuff and just update the e-mail address if that's what we want to do.
    if params[:type_of_reg] == 'guest_checkout' and current_order.state == 'address'
      current_order.state = 'cart'
      current_order.update_attribute :state, 'cart'

      current_order.reload

      if current_order.update_attributes(params[:order])
        current_order.state = 'address'
        current_order.update_attribute :state, 'address'

        redirect_to checkout_state_path(current_order.state)
      else
        render 'registration'
      end

      return
    end

    fire_event("spree.user.signup", :order => current_order)
    # hack - temporarily change the state to something other than cart so we can validate the order email address
    current_order.state = current_order.checkout_steps.first
    if current_order.update_attributes(params[:order])
      redirect_to checkout_path
    else
      @user = Spree::User.new
      render 'registration'
    end
  end

  private

    def skip_state_validation?
      %w(registration update_registration).include?(params[:action])
    end

    def check_authorization
      authorize!(:edit, current_order, session[:access_token])
    end

    # Introduces a registration step whenever the +registration_step+ preference is true.
    def check_registration
      return unless Spree::Auth::Config[:registration_step]
      return if spree_current_user or current_order.email
      store_location
      redirect_to spree.checkout_registration_path
    end

    # Overrides the equivalent method defined in Spree::Core.  This variation of the method will ensure that users
    # are redirected to the tokenized order url unless authenticated as a registered user.
    def completion_route
      return order_path(@order) if spree_current_user
      spree.token_order_path(@order, @order.token)
    end
end
