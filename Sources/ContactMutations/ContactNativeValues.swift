import ActionApprovals
import Contacts
import CoreDomain
import Foundation

/// In-memory mapping only. Does not initialize a store or confer write authority.
enum ContactNativeValues {
    static func keys(_ fields: Set<ContactField>) throws -> [String] {
        guard !fields.isEmpty, fields.isSubset(of: ContactReadCapabilities.fields) else {
            throw ProviderFailure.invalidData
        }
        var keys = [CNContactIdentifierKey]
        for field in fields {
            switch field {
            case .name: keys += [CNContactGivenNameKey, CNContactFamilyNameKey]
            case .emailAddresses: keys.append(CNContactEmailAddressesKey)
            case .phoneNumbers: keys.append(CNContactPhoneNumbersKey)
            case .postalAddresses: keys.append(CNContactPostalAddressesKey)
            case .organization: keys.append(CNContactOrganizationNameKey)
            case .notes: throw ProviderFailure.invalidData
            }
        }
        return keys.sorted()
    }
    static func request(keys: [String]) -> CNContactFetchRequest {
        let request = CNContactFetchRequest(keysToFetch: keys.map { $0 as CNKeyDescriptor })
        request.unifyResults = false
        request.mutableObjects = false
        request.sortOrder = .none  // Sorting by a hidden name must not affect membership or order.
        return request
    }
    static func normalize(
        _ value: CNContact, reference: ContactRecordReference, fields: Set<ContactField>
    ) throws -> Contact {
        guard value.identifier == reference.item.rawValue,
            value.areKeysAvailable(try keys(fields).map { $0 as CNKeyDescriptor })
        else { throw ProviderFailure.invalidData }
        var bytes = 0
        func text(_ value: String) throws -> String {
            bytes += value.utf8.count
            guard value.utf8.count <= 4096, bytes <= 16384 else {
                throw ProviderFailure.invalidData
            }
            return value
        }
        func array<T>(_ values: [T]) throws -> [T] {
            guard values.count <= 32 else { throw ProviderFailure.invalidData }
            return values
        }
        let name: FieldValue<ContactName> =
            fields.contains(.name)
            ? .value(try ContactName(given: text(value.givenName), family: text(value.familyName)))
            : .notFetched
        let emails: FieldValue<[LabeledValue<String>]> =
            fields.contains(.emailAddresses)
            ? .value(
                try array(value.emailAddresses).map {
                    try LabeledValue(label: $0.label.map(text), value: text($0.value as String))
                }) : .notFetched
        let phones: FieldValue<[LabeledValue<String>]> =
            fields.contains(.phoneNumbers)
            ? .value(
                try array(value.phoneNumbers).map {
                    try LabeledValue(label: $0.label.map(text), value: text($0.value.stringValue))
                }) : .notFetched
        let addresses: FieldValue<[LabeledValue<PostalAddress>]> =
            fields.contains(.postalAddresses)
            ? .value(
                try array(value.postalAddresses).map {
                    try LabeledValue(
                        label: $0.label.map(text),
                        value: PostalAddress(
                            street: text($0.value.street), city: text($0.value.city),
                            region: text($0.value.state), postalCode: text($0.value.postalCode),
                            country: text($0.value.country)))
                }) : .notFetched
        let organization: FieldValue<String?> =
            fields.contains(.organization)
            ? .value(try text(value.organizationName).isEmpty ? nil : value.organizationName)
            : .notFetched
        // Never export notes, linked IDs or mutation authority.
        return Contact(
            id: .record(reference), name: name, emailAddresses: emails, phoneNumbers: phones,
            postalAddresses: addresses, organization: organization)
    }
    static func apply(_ patch: ContactChanges, to value: CNMutableContact) throws {
        guard !patch.notes.isChanged else { throw ActionFailure.invalid }
        if case .set(let name) = patch.name {
            value.givenName = name.given
            value.familyName = name.family
        }
        if case .set(let emails) = patch.emailAddresses {
            value.emailAddresses = emails.map {
                CNLabeledValue(label: $0.label, value: $0.value as NSString)
            }
        }
        if case .set(let phones) = patch.phoneNumbers {
            value.phoneNumbers = phones.map {
                CNLabeledValue(label: $0.label, value: CNPhoneNumber(stringValue: $0.value))
            }
        }
        if case .set(let organization) = patch.organization {
            value.organizationName = organization ?? ""
        }
        if case .set(let addresses) = patch.postalAddresses {
            // The domain does not model these components. Never silently erase an existing one.
            guard
                value.postalAddresses.allSatisfy({
                    $0.value.subLocality.isEmpty && $0.value.subAdministrativeArea.isEmpty
                        && $0.value.isoCountryCode.isEmpty
                })
            else { throw ActionFailure.invalid }
            value.postalAddresses = addresses.map { item in
                let address = CNMutablePostalAddress()
                address.street = item.value.street
                address.city = item.value.city
                address.state = item.value.region
                address.postalCode = item.value.postalCode
                address.country = item.value.country
                return CNLabeledValue(label: item.label, value: address as CNPostalAddress)
            }
        }
    }
}
