//
//  BoxResource.swift
//  subber-api
//
//  Created by Hakon Hanesand on 11/12/16.
//
//

import Foundation
import Vapor
import HTTP
import Fluent

final class BoxController: ResourceRepresentable {

    func index(_ request: Request) throws -> ResponseRepresentable {
        
        let curated = try request.extract() as Box.Curated
        let sorted = try request.extract() as Box.Sort
        
        let query = try curated.makeQuery().apply(sorted)
        
        let format = try request.extract() as Box.Format

        return try format.apply(on: query.all()).makeJSON()
    }
    
    func show(_ request: Request, box: Box) throws -> ResponseRepresentable {
        let format = try request.extract() as Box.Format
        return try format.apply(on: box).makeJSON()
    }

    func create(_ request: Request) throws -> ResponseRepresentable {
        
        var node = try request.json().node
        let bullets = try node.extract("bullets") as [String]
        node["bullets"] = Node.string(bullets.joined(separator: Box.boxBulletSeparator))
        
        try print(node.extract("bullets") as String)
        
        var box = try Box(node: node)
        try box.save()
        return try Response(status: .created, json: box.makeJSON())
    }

    func delete(_ request: Request, box: Box) throws -> ResponseRepresentable {
        try box.delete()
        return Response(status: .noContent)
    }

    func makeResource() -> Resource<Box> {
        return Resource(
            index: index,
            store: create,
            show: show,
            destroy: delete
        )
    }
}
