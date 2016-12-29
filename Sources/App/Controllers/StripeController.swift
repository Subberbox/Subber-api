//
//  StripeController.swift
//  subber-api
//
//  Created by Hakon Hanesand on 11/21/16.
//
//

import Foundation
import Vapor
import HTTP

enum StripeModel: String, TypesafeOptionsParameter {
    case customer
    case payment
    
    static let key = "type"
    static let values = [StripeModel.customer.rawValue]
    static let defaultValue: StripeModel? = nil
}

extension Request {
    
    var sourceToken: String? {
        return query?["source"]?.string
    }
}

final class StripeController: ResourceRepresentable {

    init() {
        StripeWebhookCollection.shared.registerHandler(forResource: .account, action: .updated) { (resource, action, request) throws -> Response in
            return Response(status: .noContent)
        }
    }
    
    func create(_ request: Request) throws -> ResponseRepresentable {
        let type = try request.extract() as StripeModel
        
        switch type {
        case .customer:
            var customer = try request.customer()
            
            if let token = request.sourceToken {
                
                if customer.stripe_id == nil {
                    try Stripe.shared.createStripeCustomer(forUser: &customer, withPaymentSource: token)
                    return try Response(status: .created, json: customer.makeJSON())
                } else {
                    try Stripe.shared.associate(paymentSource: token, withCustomer: customer)
                    return Response(status: .noContent)
                }
            }
        case .payment:
            return Response(status: .notImplemented)
        }
        
        throw Abort.custom(status: .badRequest, message: "Missing type from query string.")
    }

    func delete(_ request: Request, customer: Customer) throws -> ResponseRepresentable {
        let type = try request.extract() as StripeModel

        switch type {
        case .customer:
            return Response(status: .notImplemented)

        case .payment:
            guard let id = request.query?["id"]?.string else {
                throw Abort.custom(status: .badRequest, message: "Missing id of payment to delete.")
            }

            return try Stripe.shared.deletePayment(with: id, for: customer).makeResponse()
        }
    }
    
    func makeResource() -> Resource<Customer> {
        return Resource(
            store: create,
            destroy: delete
        )
    }
}
