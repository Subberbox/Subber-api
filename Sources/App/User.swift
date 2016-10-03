//
//  File.swift
//  subber-api
//
//  Created by Hakon Hanesand on 9/27/16.
//
//

import Vapor
import Fluent
import Auth
import Turnstile
import BCrypt

final class User: Model, Preparation, NodeInitializable, NodeRepresentable, Entity {
    
    var id: Node?
    var exists = false
    
    let name: String
    let phone: String
    let stripe_id: String
    let email: String
    let password: String
    
    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        name = try node.extract("name")
        phone = try node.extract("phone")
        stripe_id = try node.extract("stripe_id")
        email = try node.extract("email")
        password = try node.extract("password")
    }
    
    init(id: String? = nil, name: String, phone: String, stripe_id: String, email: String, password: String) {
        self.id = id.flatMap { .string($0) }
        self.name = name
        self.phone = phone
        self.stripe_id = stripe_id
        self.email = email
        self.password = password
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id" : id!,
            "name" : .string(name),
            "phone" : .string(phone),
            "stripe_id" : .string(stripe_id),
            "email" : .string(email),
            "password" : .string(password)
        ])
    }
    
    static func prepare(_ database: Database) throws {
        try database.create(self.entity, closure: { box in
            box.id()
            box.string("name")
            box.string("phone")
            box.string("stripe_id")
            box.string("email")
            box.string("password")
        })
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self.entity)
    }
}

extension User {
    
    func reviews() -> Children<Review> {
        return children()
    }
    
    func shippingAddresses() -> Children<Shipping> {
        return children()
    }
    
    func sessions() -> Children<Session> {
        return children()
    }
}

extension User: Auth.User {
    
    static func authenticate(credentials: Credentials) throws -> Auth.User {
        
        let user: User
        
        switch credentials {
            
        case let token as AccessToken:
            let query = try Session.query().filter("token", token.string)
            
            guard let _user = try query.first()?.user().first() else {
                throw AuthError.invalidCredentials
            }
            
            user = _user
            
        case let usernamePassword as UsernamePassword:
            let hashedPassword = BCrypt.hash(password: usernamePassword.password)
            let query = try User.query().filter("usrname", usernamePassword.username).filter("password", hashedPassword)
            
            guard let _user = try query.first() else {
                throw AuthError.invalidCredentials
            }
            
            user = _user
            
        default:
            throw AuthError.noAuthorizationHeader
        }
        
        return user
    }
    
    static func register(credentials: Credentials) throws -> Auth.User {
        throw AuthError.notAuthenticated
    }
}
