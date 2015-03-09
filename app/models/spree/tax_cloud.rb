module Spree
  class TaxCloud
    def self.transaction_from_order(order)
      stock_location = order.shipments.first.try(:stock_location) || Spree::StockLocation.valid.first
      Spree.t(:ensure_one_valid_stock_location) unless stock_location

      transaction = ::TaxCloud::Transaction.new(
        customer_id: order.user_id || order.email,
        order_id: order.number,
        cart_id: order.number,
        origin: address_from_spree_address(stock_location),
        destination: address_from_spree_address(order.ship_address || order.billing_address)
      )

      index = -1 # array is zero-indexed
      # Prepare line_items for lookup
      order.line_items.each { |line_item| transaction.cart_items << cart_item_from_item(line_item, index += 1) }
      # Prepare shipments for lookup
      order.shipments.each { |shipment| transaction.cart_items << cart_item_from_item(shipment, index += 1) }
      transaction
    end

    # Note that this method can take either a Spree::StockLocation (which has address
    # attributes directly on it) or a Spree::Address object
    def self.address_from_spree_address(address)
      ::TaxCloud::Address.new(
        address1: address.address1,
        address2: address.address2,
        city:     address.city,
        state:    address.try(:state).try(:abbr),
        zip5:     address.zipcode.try(:[], 0...5)
      )
    end

    def self.cart_item_from_item(item, index)
      if item.class.name.demodulize == "LineItem"
        line_item = item
        ::TaxCloud::CartItem.new(
        index:      index,
        item_id:    line_item.try(:variant).try(:sku).present? ? line_item.try(:variant).try(:sku) : ("LineItem " + line_item.id.to_s),
        tic:        (line_item.product.tax_cloud_tic || Spree::Config.taxcloud_default_product_tic),
        price:      line_item.price,
        quantity:   line_item.quantity
        )
      elsif item.class.name.demodulize == "Shipment"
        shipment = item
        ::TaxCloud::CartItem.new(
        index:      index,
        item_id:    "Shipment " + shipment.number,
        tic:        Spree::Config.taxcloud_shipping_tic,
        price:      shipment.cost,
        quantity:   1
        )
      else
        raise Spree.t(:cart_item_cannot_be_made)
      end
    end
  end
end
