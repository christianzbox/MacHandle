public struct ContactRecordReference: Hashable, Sendable {
    public let container: ContactContainerReference
    public let item: ContactID

    public init(container: ContactContainerReference, item: ContactID) {
        self.container = container
        self.item = item
    }
}

public enum ContactReference: Hashable, Sendable {
    case record(ContactRecordReference)
    /// A unified view can span accounts/containers; it is not an underlying writable record.
    case unified(provider: ProviderID, store: StoreID, item: ContactID)
}

public enum ContactField: Hashable, Sendable {
    case name, emailAddresses, phoneNumbers, postalAddresses, organization, notes
}

public struct ContactName: Hashable, Sendable {
    public let given: String
    public let family: String

    public init(given: String, family: String) {
        self.given = given
        self.family = family
    }
}

public struct LabeledValue<Value: Hashable & Sendable>: Hashable, Sendable {
    public let label: String?
    public let value: Value

    public init(label: String?, value: Value) {
        self.label = label
        self.value = value
    }
}

public struct PostalAddress: Hashable, Sendable {
    public let street: String
    public let city: String
    public let region: String
    public let postalCode: String
    public let country: String

    public init(street: String, city: String, region: String, postalCode: String, country: String) {
        self.street = street
        self.city = city
        self.region = region
        self.postalCode = postalCode
        self.country = country
    }
}

/// Explicit supported fields, never a provider dictionary or automatic whole-record export.
public struct Contact: Hashable, Sendable {
    public let id: ContactReference
    public let linkedRecords: FieldValue<Set<ContactRecordReference>>
    public let name: FieldValue<ContactName>
    public let emailAddresses: FieldValue<[LabeledValue<String>]>
    public let phoneNumbers: FieldValue<[LabeledValue<String>]>
    public let postalAddresses: FieldValue<[LabeledValue<PostalAddress>]>
    public let organization: FieldValue<String?>
    public let notes: FieldValue<String?>
    public let revision: MutationPrecondition

    public init(
        id: ContactReference, linkedRecords: FieldValue<Set<ContactRecordReference>> = .notFetched,
        name: FieldValue<ContactName> = .notFetched,
        emailAddresses: FieldValue<[LabeledValue<String>]> = .notFetched,
        phoneNumbers: FieldValue<[LabeledValue<String>]> = .notFetched,
        postalAddresses: FieldValue<[LabeledValue<PostalAddress>]> = .notFetched,
        organization: FieldValue<String?> = .notFetched, notes: FieldValue<String?> = .notFetched,
        revision: MutationPrecondition = .unknown
    ) {
        self.id = id
        self.linkedRecords = linkedRecords
        self.name = name
        self.emailAddresses = emailAddresses
        self.phoneNumbers = phoneNumbers
        self.postalAddresses = postalAddresses
        self.organization = organization
        self.notes = notes
        self.revision = revision
    }
}
