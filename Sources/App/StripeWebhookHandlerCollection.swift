//
//  StripeWebhookHandlerCollection.swift
//  subber-api
//
//  Created by Hakon Hanesand on 1/2/17.
//
//

import Foundation
import HTTP
import Routing
import Vapor
import Stripe

func extractFrom<T: Model>(metadata: [String : Node]) throws -> T? {
    return try metadata[T.entity]?.string.flatMap { try T(from: $0) }
}

class StripeWebhookCollection {

    required init() {

        StripeWebhookManager.shared.registerHandler(forResource: .account, action: .updated) { (resource, action, request) -> Response in
            return Response(status: .ok)
        }

        StripeWebhookManager.shared.registerHandler(forResource: .invoice, action: .created) { (resource, action, request) -> Response in

            guard let node = request.json?.makeNode() else {
                throw Abort.custom(status: .internalServerError, message: "Unable to parse node.")
            }

            guard let metadata = node["data", "object", "lines", "data", 0, "metadata"]?.nodeObject else {
                throw Abort.custom(status: .badRequest, message: "could not extract metadata")
            }

            guard let subscription: Subscription = try extractFrom(metadata: metadata),
                  let vendor: Vendor = try extractFrom(metadata: metadata),
                  let customer: Customer = try extractFrom(metadata: metadata),
                  let shipping: Shipping = try extractFrom(metadata: metadata),
                  let box: Box = try extractFrom(metadata: metadata)
            else {
                throw Abort.custom(status: .internalServerError, message: "Wrong or missing metadata \(metadata)")
            }

            guard let invoice_id = node["data", "object", "id"]?.string else {
                throw Abort.custom(status: .badRequest, message: "could not find order id")
            }

            var order = Order(with: subscription.id, vendor_id: vendor.id, box_id: box.id, shipping_id: shipping.id, customer_id: customer.id, order_id: invoice_id)
            try order.save()

            let _ = try Stripe.shared.updateInvoiceMetadata(for: order.id!.int!, invoice_id: invoice_id)

            return try Response(status: .ok, json: Node(node: ["status" : "ok"]).makeJSON())
        }
    }
}