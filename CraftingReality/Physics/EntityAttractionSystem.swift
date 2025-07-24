/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Defines a RealityKit system that applies an attractive force to all other
 entities in the system component.
*/

import RealityKit

struct EntityAttractionSystem: System {
    // Convenience property for the update method.
    let entityQuery: EntityQuery
    let centerEntityQuery: EntityQuery

    init(scene: RealityKit.Scene) {
        let attractionComponentType = EntityAttractionComponent.self
        entityQuery = EntityQuery(where: .has(attractionComponentType))
        centerEntityQuery = EntityQuery(where: .has(FollowComponent.self))
    }

    func update(context: SceneUpdateContext) {
      
        let entities = context.entities(
            matching: entityQuery,
            updatingSystemWhen: .rendering
        )
      
        let centerEntity = context.entities(matching: centerEntityQuery, updatingSystemWhen: .rendering).first(where: { $0.components.has(FollowComponent.self) })?.children.first!
        //print(centerEntity ?? "center not found i guess")

        for case let entity as ModelEntity in entities {
            var aggregateForce: SIMD3<Float>

            // Start with a force back to the center.
            let centerForceStrength = Float(0.05)
            let position = entity.position(relativeTo: centerEntity)
            let distanceSquared = length_squared(position)

            // Set the initial force with the inverse-square law.
            aggregateForce = normalize(position) / distanceSquared

            // Direct the force back to the center by negating the position vector.
            aggregateForce *= -centerForceStrength
            
            let neighbors = context.entities(matching: entityQuery,
                                             updatingSystemWhen: .rendering)

            for neighbor in neighbors where neighbor != entity {

                let entityPosition = entity.position(relativeTo: nil)
                let neighborPosition = neighbor.position(relativeTo: nil)

                let distance = length(neighborPosition - entityPosition)

                // Calculate the force from the entity to the neighbor.
                let forceFactor = Float(0.05)
                let forceVector = normalize(neighborPosition - entityPosition)
                let neighborForce = forceFactor * forceVector / pow(distance, 2)
                aggregateForce += neighborForce
            }

            // Add the combined force from all the entity's neighbors.
            entity.addForce(aggregateForce, relativeTo: nil)
        }
    }
}
