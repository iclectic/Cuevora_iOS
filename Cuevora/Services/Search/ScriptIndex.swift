import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

enum ScriptIndex {
    private static let domain = "scripts"

    static func sync(_ scripts: [Script]) {
        let items = scripts.map { script in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = script.displayTitle
            attributes.contentDescription = String(script.content.prefix(500))
            attributes.keywords = script.tags
            return CSSearchableItem(uniqueIdentifier: script.identity.uuidString, domainIdentifier: domain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items, completionHandler: nil)
        }
    }
}
