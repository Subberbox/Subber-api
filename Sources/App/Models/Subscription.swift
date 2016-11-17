//
//  Subscription.swift
//  subber-api
//
//  Created by Hakon Hanesand on 9/27/16.
//
//

import Vapor
import Fluent
import Foundation

extension Date {
    
    init(ISO8601String: String) throws {
        let dateFormatter = DateFormatter()
        let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        guard let date = dateFormatter.date(from: ISO8601String) else {
            throw Abort.custom(status: .internalServerError, message: "Error parsing date string : \(ISO8601String)")
        }
        
        self = date
    }
    
    var ISO8601String: String {
        let dateFormatter = DateFormatter()
        let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        return dateFormatter.string(from: self)
    }
}

extension Date: NodeConvertible {
    
    public func makeNode(context: Context = EmptyNode) throws -> Node {
        return .string(self.ISO8601String)
    }
    
    public init(node: Node, in context: Context) throws {
        guard let string = node.string else {
            throw Abort.custom(status: .internalServerError, message: "Failed to parse date from node : \(node)")
        }
        
        self = try Date(ISO8601String: string)
    }
}

enum Frequency: String, StringInitializable {
    case once = "once"
    case monthly = "monthly"
    
    init?(from string: String) throws {
        guard let frequency = Frequency.init(rawValue: string) else {
            throw Abort.custom(status: .badRequest, message: "Invalid value for frequency. Can be once or monthly.")
        }
        
        self = frequency
    }
}

final class Subscription: Model, Preparation, JSONConvertible, FastInitializable {
    
    static var requiredJSONFields = ["box_id", "shipping_id", "customer_id"]
    
    var id: Node?
    var exists = false
    
    let date: Date
    let active: Bool
    let frequency: Frequency
    
    var box_id: Node?
    var shipping_id: Node?
    var customer_id: Node?
    
    var sub_id: String?
    
    init(node: Node, in context: Context) throws {
        id = try? node.extract("id")
        
        date = (try? node.extract("date")) ?? Date()
        active = (try? node.extract("active")) ?? true
        
        frequency = try node.extract("frequency") { (freq: String) in
            return Frequency.init(rawValue: freq)
        } ?? .monthly
        
        box_id = try node.extract("box_id")
        shipping_id = try node.extract("shipping_id")
        customer_id = try node.extract("customer_id")
        
        sub_id = try? node.extract("sub_id")
    }
    
    init(withId id: String, box: Box, user: Customer, shipping: Shipping, freq: Frequency = .monthly) {
        sub_id = id
        box_id = box.id
        customer_id = user.id
        shipping_id = shipping.id
        date = Date()
        active = true
        frequency = freq
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "date" : .string(date.ISO8601String),
            "active" : .bool(active),
            "box_id" : box_id!,
            "shipping_id" : shipping_id!,
            "customer_id" : customer_id!,
            "frequency" : .string(frequency.rawValue)
        ]).add(objects: ["id" : id,
                         "sub_id" : sub_id])
    }
    
    static func prepare(_ database: Database) throws {
        try database.create(self.entity, closure: { subscription in
            subscription.id()
            subscription.string("date")
            subscription.bool("active")
            subscription.string("sub_id")
            subscription.string("frequency")
            subscription.parent(Box.self, optional: false)
            subscription.parent(Shipping.self, optional: false)
            subscription.parent(Customer.self, optional: false)
        })
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self.entity)
    }
}

extension Subscription {
    
    func orders() -> Children<Order> {
        return children()
    }
    
    func address() throws -> Parent<Shipping> {
        return try parent(shipping_id)
    }
    
    func box() throws -> Parent<Box> {
        return try parent(box_id)
    }
    
    func user() throws -> Parent<Customer> {
        return try parent(customer_id)
    }
}

extension Subscription: Relationable {

    typealias Relations = (orders: [Order], address: Shipping, box: Box)
    
    func relations() throws -> (orders: [Order], address: Shipping, box: Box) {
        let orders = try self.orders().all()
        
        guard let shipping = try self.address().get() else {
            throw Abort.custom(status: .internalServerError, message: "Missing box relation for subscription with id \(id)")
        }
        
        guard let box = try self.box().get() else {
            throw Abort.custom(status: .internalServerError, message: "Missing box relation for subscription with id \(id)")
        }
        
        return (orders, shipping, box)
    }
}