import CircuiteFoundation

extension PDKProfileClaim {
    /// Compares every claim field under the supplied invocation's work limits.
    /// Keep the original decoded owners alive while comparing their borrowed backing.
    public func matchesExactly(_ other: PDKProfileClaim,
                              resources: any PDKAdmissionResourceAccounting) throws(PDKProfileValueError) -> Bool {
        let comparison = PDKProfileClaimComparison(work: PDKProfileConstructionWork(resources))
        try comparison.work.check()
        let result = try comparison.equal(self, other)
        try comparison.work.check()
        return result
    }
}

/// Borrowed structural traversal; no encoded or copied payload is needed for equality.
private struct PDKProfileClaimComparison {
    let work: PDKProfileConstructionWork

    func array<Element>(_ lhs: [Element], _ rhs: [Element],
                        equal: (Element, Element) throws(PDKProfileValueError) -> Bool) throws(PDKProfileValueError) -> Bool {
        try work.step()
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices {
            try work.step()
            if try !equal(lhs[index], rhs[index]) { return false }
        }
        return true
    }

    func strings(_ lhs: [String], _ rhs: [String]) throws(PDKProfileValueError) -> Bool {
        try array(lhs, rhs, equal: work.equal)
    }

    func digest(_ lhs: ContentDigest, _ rhs: ContentDigest) throws(PDKProfileValueError) -> Bool {
        try work.step()
        guard lhs.algorithm == rhs.algorithm else { return false }
        return try work.equal(lhs.hexadecimalValue, rhs.hexadecimalValue)
    }

    func equal(_ lhs: PDKProfileClaim, _ rhs: PDKProfileClaim) throws(PDKProfileValueError) -> Bool {
        guard try work.equal(lhs.definitionReference, rhs.definitionReference),
              try definition(lhs.definition, rhs.definition),
              try work.equal(lhs.manifestReference, rhs.manifestReference),
              try array(lhs.corners, rhs.corners, equal: corner),
              try array(lhs.selections, rhs.selections, equal: selection),
              try array(lhs.sourceClosure, rhs.sourceClosure, equal: source),
              try array(lhs.dependencies, rhs.dependencies, equal: work.equal),
              try strings(lhs.mandatorySupportSourceKeys, rhs.mandatorySupportSourceKeys) else { return false }
        return try digest(lhs.semanticSelectionDigest, rhs.semanticSelectionDigest)
    }

    func definition(_ lhs: PDKProfileDefinition, _ rhs: PDKProfileDefinition) throws(PDKProfileValueError) -> Bool {
        guard try work.equal(lhs.profileID, rhs.profileID),
              try work.equal(lhs.manifestReference, rhs.manifestReference),
              try work.equal(lhs.processID, rhs.processID),
              try work.equal(lhs.version, rhs.version),
              try strings(lhs.requiredCornerIDs, rhs.requiredCornerIDs),
              try array(lhs.requirements, rhs.requirements, equal: requirement),
              try array(lhs.sources, rhs.sources, equal: source),
              try strings(lhs.orderedSearchRoutes, rhs.orderedSearchRoutes),
              try array(lhs.dependencies, rhs.dependencies, equal: work.equal),
              try work.equal(lhs.inspectionPolicyIdentity, rhs.inspectionPolicyIdentity) else { return false }
        return try work.equal(lhs.initialPreprocessingIdentity, rhs.initialPreprocessingIdentity)
    }

    func requirement(_ lhs: PDKViewRequirement, _ rhs: PDKViewRequirement) throws(PDKProfileValueError) -> Bool {
        try work.step()
        guard lhs.view == rhs.view, lhs.role == rhs.role, lhs.isShared == rhs.isShared,
              lhs.allowsMultipleSources == rhs.allowsMultipleSources else { return false }
        guard try work.equal(lhs.requirementID, rhs.requirementID),
              try work.equal(lhs.purposeID, rhs.purposeID),
              try strings(lhs.assetIDs, rhs.assetIDs),
              try strings(lhs.cornerIDs, rhs.cornerIDs),
              try work.equal(lhs.selectedSection, rhs.selectedSection) else { return false }
        return try strings(lhs.demandedFactKinds, rhs.demandedFactKinds)
    }

    func source(_ lhs: PDKProfileSource, _ rhs: PDKProfileSource) throws(PDKProfileValueError) -> Bool {
        guard try work.equal(lhs.sourceKey, rhs.sourceKey),
              try work.equal(lhs.assetID, rhs.assetID),
              try work.equal(lhs.reference, rhs.reference) else { return false }
        return try strings(lhs.logicalRoutes, rhs.logicalRoutes)
    }

    func corner(_ lhs: PDKProfileCorner, _ rhs: PDKProfileCorner) throws(PDKProfileValueError) -> Bool {
        try work.step()
        guard lhs.pvt.voltage == rhs.pvt.voltage, lhs.pvt.temperatureCelsius == rhs.pvt.temperatureCelsius,
              lhs.pvt.process.nominal == rhs.pvt.process.nominal else { return false }
        guard try work.equal(lhs.cornerID, rhs.cornerID) else { return false }
        return try work.equal(lhs.pvt.process.name, rhs.pvt.process.name)
    }

    func selection(_ lhs: PDKProfileSelection, _ rhs: PDKProfileSelection) throws(PDKProfileValueError) -> Bool {
        guard try work.equal(lhs.requirementID, rhs.requirementID),
              try work.equal(lhs.cornerID, rhs.cornerID),
              try strings(lhs.assetIDs, rhs.assetIDs),
              try strings(lhs.sourceKeys, rhs.sourceKeys) else { return false }
        return try work.equal(lhs.selectedSection, rhs.selectedSection)
    }
}
