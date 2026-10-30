import ActionApprovals
import Contacts
import CoreDomain
import Testing

@testable import ContactMutations

@Test func contactPatchPreservesUnrelatedNativeFieldsAndReplacesOnlyChosenArrays() throws {
    let native = CNMutableContact()
    native.givenName = "Sample"
    native.familyName = "Contact"
    native.middleName = "Preserved"
    native.organizationName = "Original"
    native.note = "synthetic-hidden-note"
    native.emailAddresses = [CNLabeledValue(label: "Old", value: "old@example.invalid" as NSString)]
    let patch = try ContactChanges(
        emailAddresses: .set([LabeledValue(label: "New", value: "new@example.invalid")]),
        organization: .set(nil))
    try ContactNativeValues.apply(patch, to: native)
    #expect(
        native.emailAddresses.count == 1 && native.emailAddresses[0].value == "new@example.invalid")
    #expect(native.emailAddresses[0].label == "New" && native.organizationName.isEmpty)
    #expect(
        native.givenName == "Sample" && native.middleName == "Preserved"
            && native.note == "synthetic-hidden-note")
    #expect(throws: (any Error).self) {
        try ContactNativeValues.apply(ContactChanges(notes: .set("forbidden")), to: native)
    }
}
@Test func contactNativeKeysStayMinimalAndPostalFidelityLossIsDenied() throws {
    #expect(
        try Set(ContactNativeValues.keys([.name, .organization])) == [
            CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactOrganizationNameKey,
        ])
    #expect(!ContactNativeValues.request(keys: [CNContactIdentifierKey]).unifyResults)
    let contact = CNMutableContact()
    let address = CNMutablePostalAddress()
    address.street = "Sample street"
    address.subLocality = "Must not erase"
    contact.postalAddresses = [CNLabeledValue(label: nil, value: address as CNPostalAddress)]
    #expect(throws: (any Error).self) {
        try ContactNativeValues.apply(ContactChanges(postalAddresses: .set([])), to: contact)
    }
    #expect(contact.postalAddresses[0].value.subLocality == "Must not erase")
}
@Test func allSupportedContactFieldGroupsMapWithoutFetchingNotes() throws {
    let contact = CNMutableContact()
    let patch = try ContactChanges(
        name: .set(ContactName(given: "Sample", family: "Example")), emailAddresses: .set([]),
        phoneNumbers: .set([LabeledValue(label: nil, value: "555-0100")]),
        postalAddresses: .set([
            LabeledValue(
                label: "Sample",
                value: PostalAddress(
                    street: "Example", city: "Sample", region: "MI", postalCode: "00000",
                    country: "US"))
        ]), organization: .set("Sample"))
    try ContactNativeValues.apply(patch, to: contact)
    #expect(contact.givenName == "Sample" && contact.phoneNumbers.count == 1)
    #expect(contact.postalAddresses[0].value.street == "Example" && contact.note.isEmpty)
}
