#!/usr/bin/env python3
"""Prints App Store status details (versions, availability, price) as annotations.

Read-only: it changes nothing in App Store Connect.
"""
import collections
import sys

from testflight_external import BUNDLE_ID, call


def note(title, msg):
    print(f"::notice title={title}::{msg}")


def main():
    app = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]
    app_id = app["id"]

    versions = call("GET", f"/v1/apps/{app_id}/appStoreVersions?limit=5")["data"]
    for v in versions:
        a = v["attributes"]
        note("Version", f"{a.get('versionString')} appStoreState={a.get('appStoreState')} "
                        f"appVersionState={a.get('appVersionState')} releaseType={a.get('releaseType')}")

    avail = call("GET", f"/v1/apps/{app_id}/appAvailabilityV2", ok_missing=True)
    if not avail:
        note("Availability", "No app availability record: territories were never set up")
    else:
        av_id = avail["data"]["id"]
        note("Availability", f"availableInNewTerritories={avail['data']['attributes'].get('availableInNewTerritories')}")
        rows, path = [], f"/v2/appAvailabilities/{av_id}/territoryAvailabilities?limit=200&include=territory"
        while path:
            page = call("GET", path)
            rows += page["data"]
            nxt = page.get("links", {}).get("next")
            path = nxt.replace("https://api.appstoreconnect.apple.com", "") if nxt else None
        available = [r for r in rows if r["attributes"].get("available")]
        statuses = collections.Counter(s for r in rows for s in (r["attributes"].get("contentStatuses") or []))
        mys = [r for r in rows if r["relationships"]["territory"]["data"]["id"] in ("MYS", "USA")]
        note("Territories", f"{len(available)} of {len(rows)} available. Content statuses: {dict(statuses)}")
        for r in mys:
            a = r["attributes"]
            note("Territory " + r["relationships"]["territory"]["data"]["id"],
                 f"available={a.get('available')} statuses={a.get('contentStatuses')} releaseDate={a.get('releaseDate')}")

    price = call("GET", f"/v1/apps/{app_id}/appPriceSchedule", ok_missing=True)
    note("Price schedule", "set" if price else "NOT set")


if __name__ == "__main__":
    sys.exit(main())
