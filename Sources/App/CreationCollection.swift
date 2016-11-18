//
//  CreationCollection.swift
//  subber-api
//
//  Created by Hakon Hanesand on 10/19/16.
//
//

import Foundation
import Vapor
import HTTP
import Routing
import JSON
import Auth

func perform<T>(_ failureMessage: String, throwable: () throws -> T) rethrows -> T {

    do {
        return try throwable()
    } catch {
        throw Abort.custom(status: .badRequest, message: failureMessage + " . Underlying error \(error)")
    }
}

func perform(_ failureMessage: String, throwable: () throws -> ()) rethrows {
    
    do {
        try throwable()
    } catch {
        throw Abort.custom(status: .badRequest, message: failureMessage + " . Underlying error \(error)")
    }
}

extension Message {
    
    public func json() throws -> JSON {
        if let existing = storage["json"] as? JSON {
            return existing
        } else if let type = headers["Content-Type"], type.contains("application/json") {
            guard case let .data(body) = body else { throw Abort.custom(status: .badRequest, message: "Unable to decode body.") }
            let json = try JSON(bytes: body)
            storage["json"] = json
            return json
        } else {
            throw Abort.custom(status: .badRequest, message: "Missing application/json Content-Type.")
        }
    }
}

final class CreationCollection : RouteCollection, EmptyInitializable {
    
    init () {}
    
    typealias Wrapped = HTTP.Responder
    
    typealias CreateableModel = JSONInitializable & Model & FastInitializable
    
//    private static let allowedModels: [String : CreateableModel.Type] = ["\(User.self)" : User.self,
//                                                                         "\(Vendor.self)" : Vendor.self,
//                                                                         "\(Review.self)" : Review.self,
//                                                                         "\(Category.self)" : Category.self,
//                                                                         "\(Box.self)" : Box.self,
//                                                                         "\(Subscription.self)" : Subscription.self,
//                                                                         "\(Order.self)" : Order.self]
    
    private static let allowedModelStrings = ["\(User.self)", "\(Vendor.self)", "\(Review.self)", "\(Category.self)", "\(Box.self)", "\(Order.self)", "\(Shipping.self)"]
    private static let allowedModelClasses = [User.self, Vendor.self, Review.self, Category.self, Box.self, Order.self, Shipping.self] as [Any]
    
    private static func modelClass(forString string: String) -> CreateableModel.Type? {
        guard let index = CreationCollection.allowedModelStrings.index(of: string) else {
            return nil
        }
        
        // Get around swift compiler bug (I think?)
        return CreationCollection.allowedModelClasses[index] as? CreateableModel.Type
    }
    
    func build<Builder : RouteBuilder>(_ builder: Builder) where Builder.Value == Responder {
        
        let create = builder.grouped("create")
        
        create.post(String.self) { request, table in

            guard let type = CreationCollection.modelClass(forString: table) else {
                throw Abort.custom(status: .badRequest, message: "Table \(table) is not allowed for creation API. Acceptable values are \(CreationCollection.allowedModelStrings)")
            }
            
            let json: JSON = try perform("Malformed or missing json body.") { try request.json() }
            var instance: (JSONInitializable & Model) = try perform("missing json entries or wrong type in json. Required values are \(type.requiredJSONFields). ") { try type.init(json: json) }
            
            try perform("error saving to database") { try instance.save() }
            
            return try Response(status: .created, json: instance.makeJSON())
        }
        
        let upload = builder.grouped("upload")
        
        upload.post("image", Box.self) { request, box in

            guard let fileData = request.multipart?["image"]?.file?.data else {
                throw Abort.custom(status: .badRequest, message: "No file in request")
            }
            
            guard let workPath = Droplet.instance?.workDir else {
                throw Abort.custom(status: .internalServerError, message: "Missing working directory")
            }
        
            let name = UUID().uuidString + ".png"
            let imageFolder = "Public/images"
            let saveURL = URL(fileURLWithPath: workPath).appendingPathComponent(imageFolder, isDirectory: true).appendingPathComponent(name, isDirectory: false)
            
            do {
                let data = Data(bytes: fileData)
                try data.write(to: saveURL)
            } catch {
                throw Abort.custom(status: .internalServerError, message: "Unable to write multipart form data to file. Underlying error \(error)")
            }
            
            let cloudURL = URL(string: "http://api.instacrate.me/images/")!.appendingPathComponent(name)
            var picture = Picture(url: cloudURL.absoluteString, box_id: box.id!.string!)
            try picture.save()
            
            return try picture.makeJSON()
        }
        
        upload.post("contract", Vendor.self) { request, vendor in
            guard let fileData = request.multipart?["contract"]?.file?.data else {
                throw Abort.custom(status: .badRequest, message: "No file in request")
            }
            
            guard let workPath = Droplet.instance?.workDir else {
                throw Abort.custom(status: .internalServerError, message: "Missing working directory")
            }
            
            let name = "\(vendor.parentCompanyName)_\(UUID().uuidString).txt"
            let imageFolder = "Private/Contracts/"
            let saveURL = URL(fileURLWithPath: workPath).appendingPathComponent(imageFolder, isDirectory: true).appendingPathComponent(name, isDirectory: false)
            
            do {
                let data = Data(bytes: fileData)
                try data.write(to: saveURL)
            } catch {
                throw Abort.custom(status: .internalServerError, message: "Unable to write multipart form data to file. Underlying error \(error)")
            }
            
            return Response(status: .created)
        }
    }
}