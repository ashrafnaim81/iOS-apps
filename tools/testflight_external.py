#!/usr/bin/env python3
"""Sets up external TestFlight testing through the App Store Connect API.

Fills in the beta test information, creates an external tester group with a
public link, adds the newest build to it and submits that build for Beta App
Review. Every step checks existing state first, so the script can be re-run.

Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY, REVIEW_PHONE, REVIEW_EMAIL.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

import jwt

BUNDLE_ID = "com.ashrafnaim.sudoku"
GROUP_NAME = "Rakan"
PUBLIC_LINK_LIMIT = 50
API = "https://api.appstoreconnect.apple.com"

BETA_DESCRIPTION = (
    "Sudoku Santai is a relaxing Sudoku game with a Daily Challenge, pencil notes, "
    "achievements, original music and a friendly cat mascot called Si Santai."
)
PRIVACY_URL = "https://github.com/ashrafnaim81/iOS-apps/blob/HEAD/AppStore/PRIVACY.md"
WHATS_NEW = (
    "Terima kasih kerana menguji Sudoku Santai! Cuba beberapa pusingan, Daily Challenge "
    "dan mod nota. Untuk maklum balas, ambil screenshot dan pilih Share Beta Feedback.\n\n"
    "Thanks for testing! Play a few games, the Daily Challenge and pencil notes. "
    "To send feedback, take a screenshot and choose Share Beta Feedback."
)


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"},
        os.environ["ASC_PRIVATE_KEY"],
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method, path, body=None, ok_conflict=False):
    req = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as res:
            raw = res.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as err:
        detail = err.read().decode(errors="replace")
        if ok_conflict and err.code == 409:
            print(f"  (already done: {detail[:300]})")
            return None
        print(f"::error title=App Store Connect {method} {path.split('?')[0]} -> {err.code}::{detail[:1500]}")
        sys.exit(1)


def rel(kind, ident):
    return {"data": {"type": kind, "id": ident}}


def main():
    phone = re.sub(r"[^+0-9 -]", "", os.environ.get("REVIEW_PHONE", "")).strip()
    email = re.sub(r"[^A-Za-z0-9._%+@-]", "", os.environ.get("REVIEW_EMAIL", "")).rstrip(".")

    app_id = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]["id"]
    print(f"App: {app_id}")

    # 1. Test information shown to testers in the TestFlight app.
    locs = call("GET", f"/v1/apps/{app_id}/betaAppLocalizations")["data"]
    attrs = {"description": BETA_DESCRIPTION, "feedbackEmail": email, "privacyPolicyUrl": PRIVACY_URL}
    existing = next((l for l in locs if l["attributes"]["locale"] == "en-US"), None)
    if existing:
        call("PATCH", f"/v1/betaAppLocalizations/{existing['id']}",
             {"data": {"type": "betaAppLocalizations", "id": existing["id"], "attributes": attrs}})
    else:
        call("POST", "/v1/betaAppLocalizations",
             {"data": {"type": "betaAppLocalizations", "attributes": {"locale": "en-US", **attrs},
                       "relationships": {"app": rel("apps", app_id)}}})
    print("Test information saved")

    # 2. Contact details for Beta App Review.
    detail = call("GET", f"/v1/apps/{app_id}/betaAppReviewDetail")["data"]
    call("PATCH", f"/v1/betaAppReviewDetails/{detail['id']}", {"data": {
        "type": "betaAppReviewDetails", "id": detail["id"],
        "attributes": {
            "contactFirstName": "Ashraf", "contactLastName": "Naim",
            "contactPhone": phone, "contactEmail": email,
            "demoAccountRequired": False,
            "notes": "Offline single-player Sudoku game. No account or sign-in is needed.",
        }}})
    print("Beta review contact saved")

    # 3. External tester group with a public link.
    groups = call("GET", f"/v1/apps/{app_id}/betaGroups?limit=50")["data"]
    group = next((g for g in groups if g["attributes"]["name"] == GROUP_NAME), None)
    link_attrs = {"publicLinkEnabled": True, "publicLinkLimitEnabled": True,
                  "publicLinkLimit": PUBLIC_LINK_LIMIT, "feedbackEnabled": True}
    if group:
        group = call("PATCH", f"/v1/betaGroups/{group['id']}",
                     {"data": {"type": "betaGroups", "id": group["id"], "attributes": link_attrs}})["data"]
    else:
        group = call("POST", "/v1/betaGroups",
                     {"data": {"type": "betaGroups", "attributes": {"name": GROUP_NAME, **link_attrs},
                               "relationships": {"app": rel("apps", app_id)}}})["data"]
    print(f"Group '{GROUP_NAME}' ready (public link limit {PUBLIC_LINK_LIMIT})")

    # 4. Newest processed build: notes for testers, then add it to the group.
    builds = call("GET", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10"
                         "&fields[builds]=version,processingState,expired")["data"]
    build = next((b for b in builds
                  if b["attributes"]["processingState"] == "VALID" and not b["attributes"]["expired"]), None)
    if not build:
        print("::error::No processed build found")
        sys.exit(1)
    print(f"Build: {build['attributes']['version']}")

    blocs = call("GET", f"/v1/builds/{build['id']}/betaBuildLocalizations")["data"]
    existing = next((l for l in blocs if l["attributes"]["locale"] == "en-US"), None)
    if existing:
        call("PATCH", f"/v1/betaBuildLocalizations/{existing['id']}",
             {"data": {"type": "betaBuildLocalizations", "id": existing["id"],
                       "attributes": {"whatsNew": WHATS_NEW}}})
    else:
        call("POST", "/v1/betaBuildLocalizations",
             {"data": {"type": "betaBuildLocalizations",
                       "attributes": {"locale": "en-US", "whatsNew": WHATS_NEW},
                       "relationships": {"build": rel("builds", build["id"])}}})

    call("POST", f"/v1/betaGroups/{group['id']}/relationships/builds",
         {"data": [{"type": "builds", "id": build["id"]}]})
    print("Build added to group")

    # 5. Beta App Review (required once per version before external testers can install).
    call("POST", "/v1/betaAppReviewSubmissions",
         {"data": {"type": "betaAppReviewSubmissions",
                   "relationships": {"build": rel("builds", build["id"])}}}, ok_conflict=True)
    state = call("GET", f"/v1/builds/{build['id']}/buildBetaDetail")["data"]["attributes"]
    print(f"Beta review submitted; external build state: {state.get('externalBuildState')}")
    # The public link itself is not printed: this repository and its logs are public.
    print(f"::notice title=TestFlight::Group '{GROUP_NAME}' set up, build {build['attributes']['version']} "
          f"state {state.get('externalBuildState')}. Copy the public link from App Store Connect > TestFlight > {GROUP_NAME}.")


if __name__ == "__main__":
    main()
