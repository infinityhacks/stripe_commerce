require 'spec_helper'

describe Product, ".instance methods with images" do
  before(:each) do
    @product = create(:product_with_image)
  end

  context "featured_image" do
    pending "test for featured_image"
    #it 'should return an image url' do
      # @your_model.should_receive(:save_attached_files).and_return(true)
      # Image.new :photo => File.new(Rails.root + 'spec/fixtures/images/rails.png')
    #  @product.featured_image.should_not be_nil
    #end

  end
end



#def tax_rate(state_id, time = Time.zone.now)
#  TaxRate.where(["state_id = ? AND
#                         start_date <= ? AND
#                         (end_date > ? OR end_date IS NULL) AND
#                         active = ?", state_id,
#                                      time.to_date.to_s(:db),
#                                      time.to_date.to_s(:db),
#                                      true]).order('start_date DESC').first
#end

describe Product, ".tax_rate" do
  # use case tax rate end date is nil and the start_date < now
  it 'should return the tax rate' do
    tax_rate    = create(:tax_rate,
                          :state_id => 1,
                          :start_date => (Time.zone.now - 1.year),
                          :end_date => nil)
    product  = create(:product)
    product.tax_rate(1, Time.zone.now).should == tax_rate
  end
  # use case tax rate end date is next month and the start_date < now
  it 'should return the tax rate' do
    tax_rate    = create(:tax_rate,
                          :state_id => 1,
                          :start_date => (Time.zone.now - 1.year),
                          :end_date => (Time.zone.now + 1.month))
    product  = create(:product)
    product.tax_rate(1, Time.zone.now).should == tax_rate
  end
  # use case tax rate end date is one month ago and the start_date < now but the time was 2 months ago
  it 'should return the tax rate' do
    tax_rate    = create(:tax_rate,
                          :state_id => 1,
                          :start_date => (Time.zone.now - 1.year),
                          :end_date => (Time.zone.now - 1.month))
    Rails.cache.delete("TaxRate-active_at_ids-#{(Time.zone.now - 2.month).to_date}")
    product  = create(:product)
    product.tax_rate(1, (Time.zone.now - 2.month)).should == tax_rate
  end
  # there are no tax rates
  it 'should not return the tax rate' do
    product  = create(:product)
    product.tax_rate(1, (Time.zone.now - 2.month)).should be_nil
  end
  # the tax rate starts next month
  it 'should not return any tax rates' do
    tax_rate    = create(:tax_rate,
                          :state_id   => 1,
                          :start_date => (Time.zone.now - 1.month),
                          :end_date   => nil)
    product  = create(:product)
    product.tax_rate(1, (Time.zone.now - 2.month)).should be_nil
  end
  # the tax rate changes next month but is 5% now and next month will be 10%
  it 'should return any tax rates of 5%' do
    tax_rate    = create(:tax_rate,
                          :percentage => 5.0,
                          :state_id   => 1,
                          :start_date => (Time.zone.now - 1.year),
                          :end_date   => (Time.zone.now + 1.month))

    tax_rate2    = create(:tax_rate,
                          :percentage => 10.0,
                          :state_id   => 1,
                          :start_date => (Time.zone.now + 1.month),
                          :end_date   => (Time.zone.now + 1.year))
    product  = create(:product)
    product.tax_rate(1).should == tax_rate
  end

  it 'should tax the countries tax rate' do
    Settings.tax_per_state_id = false
    tax_rate    = create(:tax_rate,
                          :percentage => 5.0,
                          :country_id   => 1,
                          :start_date => (Time.zone.now - 1.year),
                          :end_date   => (Time.zone.now + 1.month))
    product  = create(:product)
    product.tax_rate(1).should == tax_rate
    Settings.tax_per_state_id = true
  end

end

describe Product, ".instance methods" do

  context 'with three variants' do
    before(:each) do
      product  = create(:product)
      @previous_master = create(:variant, :product => product, :master => true, :price => 15.05, :deleted_at => (Time.zone.now - 1.day ))
      create(:variant, :product => product, :master => true, :price => 15.01)
      create(:variant, :product => product, :master => false, :price => 10.00)
      @product  = Product.find(product.id)
    end

    context "featured_image" do

      it 'should return no_image url' do
        @product.featured_image.should        == 'no_image_small.jpg'
        @product.featured_image(:mini).should == 'no_image_mini.jpg'
      end

    end

    context ".price" do
      it 'should return the lowest price' do
        @product.price.should == 10.00
      end
    end

    context ".set_keywords=(value)" do
      it 'should set keywords' do
        @product.set_keywords             =  'hi, my, name, is, Dave'
        @product.product_keywords.should  == ['hi', 'my', 'name', 'is', 'Dave']
        @product.set_keywords.should      == 'hi, my, name, is, Dave'
      end
    end

    context ".display_price_range(j = ' to ')" do
      it 'should return the price range' do
        @product.display_price_range.should == '10.0 to 15.01'
      end
    end

    context ".price_range" do
      it 'should return the price range' do
        @product.price_range.should == [10.0, 15.01]
      end
    end

    context ".price_range?" do
      it 'should return the price range' do
        @product.price_range?.should be_true
      end
    end
  end

  context 'without variants' do
    before(:each) do
      @product  = FactoryGirl.create(:product)
    end

    context '.available?' do
      context 'with a shipping rate but no inventory' do
        it 'should be false' do
          inventory   = create(:inventory, count_on_hand: 100, count_pending_to_customer: 100)
          @variant    = create(:variant, product: @product, inventory: inventory)
          FactoryGirl.create(:shipping_rate, shipping_category: @product.shipping_category)
          expect(@product.available?).to be_false
        end
      end

      context 'with inventory but no shipping rate' do
        it 'should be false' do
          inventory   = create(:inventory, count_on_hand: 100, count_pending_to_customer: 90)
          @variant    = create(:variant, product: @product, inventory: inventory)
          expect(@product.available?).to be_false
        end
      end

      context 'with a shipping rate & inventory' do
        it 'should be true' do
          inventory   = create(:inventory, count_on_hand: 100, count_pending_to_customer: 90)
          @variant    = create(:variant, product: @product, inventory: inventory)
          FactoryGirl.create(:shipping_rate, shipping_category: @product.shipping_category)
          expect(@product.available?).to be_true
        end
      end
    end

    context '.has_shipping_method?' do
      it 'should be false without a shipping rate' do
        expect(@product.has_shipping_method?).to be_false
      end

      it 'should be true with a shipping rate' do
        inventory   = create(:inventory, count_on_hand: 100, count_pending_to_customer: 90)
        @variant    = create(:variant, product: @product, inventory: inventory)
        FactoryGirl.create(:shipping_rate, shipping_category: @product.shipping_category)
        expect(@product.has_shipping_method?).to be_true
      end
    end
  end
end


describe Product, "class methods" do

  context "#standard_search(args)" do
    it "should search products" do
      product1  = create(:product, :meta_keywords => 'no blah', :name => 'blah')
      product2  = create(:product, :meta_keywords => 'tester blah')
      product1.activate!
      product2.activate!
      args = 'tester'
      products = Product.standard_search(args)
      products.include?(product1).should be_false
      products.include?(product2).should be_true
    end
  end

  context "#preorders" do
    it "should find preorders" do
      product_type = create(:product_type )
      product_typem = create(:product_type, :name => 'Media')
      product   = create(:product, :product_type => product_type)
      product_m = create(:product, :product_type => product_typem)
      product_m.activate!
      Product.preorders.to_a.should eq [product_m]
    end
  end

  context "#admin_grid(params = {}, active_state = nil)" do

    it "should return Products " do
      product1 = create(:product)
      product2 = create(:product)
      product1.activate!
      product2.activate!
      admin_grid = Product.admin_grid({}, true)
      admin_grid.size.should == 2
      admin_grid.include?(product1).should be_true
      admin_grid.include?(product2).should be_true
    end
    it "should return deleted Products " do
      product1 = create(:product)
      product2 = create(:product)
      product1.deleted_at = Time.zone.now - 1.second
      product1.save
      product2.deleted_at = Time.zone.now + 20.seconds
      product2.save
      admin_grid = Product.admin_grid({}, false)
      admin_grid.size.should == 1
      admin_grid.include?(product1).should be_true
      admin_grid.include?(product2).should be_false
    end

    it "should return deleted Products " do
      product1 = create(:product)
      product2 = create(:product)
      admin_grid = Product.admin_grid({}, nil)
      admin_grid.size.should == 2
      admin_grid.include?(product1).should be_true
      admin_grid.include?(product2).should be_true
    end
  end
end
