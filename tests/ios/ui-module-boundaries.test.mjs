import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import test from 'node:test';

const root = 'ios/Beckon/Beckon/';
const source = path => readFileSync(root + path, 'utf8');

test('home booking action forwards its booking to the bookings destination', () => {
  const tabs = source('Features/Groomer/GroomerTabView.swift');
  assert.doesNotMatch(tabs, /bookingAction:\s*\{\s*_\s+in/);
  assert.match(tabs, /focusedBooking\s*=\s*booking/);
  assert.match(tabs, /focusedBooking:\s*\$focusedBooking/);
  assert.match(source('Features/Bookings/BookingsView.swift'), /navigationDestination\(item:\s*\$focusedBooking\)/);
});

test('wizard view delegates profile reads to its flow state', () => {
  assert.doesNotMatch(source('Features/Customer/Requests/CustomerRequestWizardView.swift'), /customerProfileRepository\.profile\(/);
});

test('quote view delegates time resolution and async initialization to form state', () => {
  const view = source('Features/Groomer/Requests/GroomerRequestsView.swift');
  assert.doesNotMatch(view, /GroomingServiceTiming\.(resolveWallInput|wallInput)/);
  assert.doesNotMatch(view, /private func (loadServiceTimeZone|initializeOfferFormIfNeeded)/);
});

test('business address state is outside the visual primitive layer', () => {
  assert.equal(existsSync(root + 'DesignSystem/BeckonAddressEditor.swift'), false);
  assert.match(source('SharedFeatures/Address/BeckonAddressEditorState.swift'), /final class BeckonAddressEditorState/);
});

test('customer and groomer fit evidence use the same visual component', () => {
  for (const path of ['Features/Customer/Requests/CustomerRequestDetailView.swift', 'Features/Groomer/Requests/GroomerRequestsView.swift']) {
    const view = source(path);
    assert.match(view, /BeckonFitEvidenceBlock\(/);
    assert.doesNotMatch(view, /private struct (CustomerOffer|Groomer)FitEvidenceBlock/);
  }
});

test('notification and chat presentation do not carry non-rendering style flags', () => {
  const notifications = existsSync(root + 'SharedFeatures/Notifications/BeckonSystemNotifications.swift')
    ? 'SharedFeatures/Notifications/BeckonSystemNotifications.swift' : 'DesignSystem/BeckonSystemNotifications.swift';
  for (const path of [notifications, 'Features/Chat/ChatView.swift']) {
    assert.doesNotMatch(source(path), /enum (PageStyle|RowStyle|BellStyle)/);
  }
});
