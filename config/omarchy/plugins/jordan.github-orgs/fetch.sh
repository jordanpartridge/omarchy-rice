#!/usr/bin/env bash
# Snapshot GitHub orgs/users into ~/.local/state/omarchy/github-orgs.json
# for the jordan.github-orgs Omarchy panel.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
mkdir -p "$STATE_DIR"
OUT="$STATE_DIR/github-orgs.json"
LOCK="$STATE_DIR/github-orgs.lock"

FORCE=0
if [[ ${1:-} == --force ]]; then
  FORCE=1
fi

exec 9>"$LOCK"
if ! flock -n 9; then
  if [[ -f $OUT ]]; then
    cat "$OUT"
    exit 0
  fi
  exit 1
fi

if (( FORCE == 0 )) && [[ -f $OUT ]]; then
  now_s=$(date +%s)
  age=$((now_s - $(stat -c %Y "$OUT")))
  if (( age >= 0 && age < 90 )); then
    cat "$OUT"
    exit 0
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  printf '%s\n' '{"updatedAt":null,"attention":0,"error":"gh is not installed","orgs":[]}'
  exit 0
fi

QUERY=$(cat <<'GQL'
query(
  $login: String!,
  $isOrg: Boolean!,
  $qIssues: String!,
  $qPrs: String!,
  $qNight: String!,
  $qAgent: String!,
  $qPark: String!,
  $qReview: String!,
  $qRecent: String!
) {
  org: organization(login: $login) @include(if: $isOrg) {
    login
    name
    avatarUrl
    url
  }
  usr: user(login: $login) @skip(if: $isOrg) {
    login
    name
    avatarUrl
    url
  }
  issues: search(query: $qIssues, type: ISSUE, first: 1) { issueCount }
  prs: search(query: $qPrs, type: ISSUE, first: 1) { issueCount }
  night: search(query: $qNight, type: ISSUE, first: 8) {
    issueCount
    nodes { ... on Issue { ...IssueBits } }
  }
  agent: search(query: $qAgent, type: ISSUE, first: 8) {
    issueCount
    nodes { ... on Issue { ...IssueBits } }
  }
  park: search(query: $qPark, type: ISSUE, first: 1) { issueCount }
  review: search(query: $qReview, type: ISSUE, first: 8) {
    issueCount
    nodes { ... on PullRequest { ...PrBits } }
  }
  recent: search(query: $qRecent, type: ISSUE, first: 5) {
    nodes { ... on Issue { ...IssueBits } }
  }
}

fragment IssueBits on Issue {
  number
  title
  url
  updatedAt
  repository { name }
  labels(first: 12) { nodes { name } }
  comments { totalCount }
}

fragment PrBits on PullRequest {
  number
  title
  url
  updatedAt
  isDraft
  reviewDecision
  repository { name }
  labels(first: 12) { nodes { name } }
  author { login }
}
GQL
)

fetch_owner() {
  local kind="$1" login="$2" short="$3"
  local prefix is_org
  if [[ $kind == org ]]; then
    prefix="org:${login}"
    is_org=true
  else
    prefix="user:${login}"
    is_org=false
  fi

  gh api graphql \
    -f query="$QUERY" \
    -f login="$login" \
    -F isOrg="$is_org" \
    -f qIssues="${prefix} is:open is:issue" \
    -f qPrs="${prefix} is:open is:pr" \
    -f qNight="${prefix} is:open is:issue label:night-ready" \
    -f qAgent="${prefix} is:open is:issue label:agent-ready" \
    -f qPark="${prefix} is:open is:issue label:park" \
    -f qReview="${prefix} is:open is:pr -is:draft (review:required OR review:changes_requested OR review-requested:@me)" \
    -f qRecent="${prefix} is:open is:issue -label:park sort:updated-desc" \
  | jq --arg login "$login" --arg kind "$kind" --arg short "$short" '
      def labels($n): [($n.labels.nodes // [])[]?.name // empty];
      def skip($n; $itemKind):
        (labels($n) | index("park") != null)
        or (($n.author.login // "") | test("dependabot|renovate|github-actions"; "i"))
        or (($n.title // "") | test("^chore: allow Laravel"; "i"));
      def why($n; $itemKind):
        if (labels($n) | index("night-ready") != null) then "night-ready"
        elif $itemKind == "pr" then "review"
        elif (labels($n) | index("agent-ready") != null) then "agent-ready"
        else "recent"
        end;
      def item($itemKind; $n):
        {
          kind: $itemKind,
          why: why($n; $itemKind),
          number: $n.number,
          title: ($n.title // ""),
          url: ($n.url // ""),
          repo: ($n.repository.name // ""),
          labels: labels($n),
          updatedAt: ($n.updatedAt // ""),
          comments: ($n.comments.totalCount // 0)
        };
      def take($itemKind; $nodes):
        [ $nodes[]? | select(.number != null) | select(skip(.; $itemKind) | not) | item($itemKind; .) ];
      def whyRank: if .why == "night-ready" then 0 elif .why == "review" then 1 elif .why == "agent-ready" then 2 else 3 end;
      (.data // {}) as $d
      | ($d.org // $d.usr // {login: $login, name: $login, avatarUrl: "", url: ("https://github.com/" + $login)}) as $owner
      | ($d.night.issueCount // 0) as $night
      | ($d.agent.issueCount // 0) as $agent
      | ($d.review.issueCount // 0) as $review
      | (take("issue"; $d.night.nodes // [])
          + take("pr"; $d.review.nodes // [])
          + take("issue"; $d.agent.nodes // [])
          + take("issue"; $d.recent.nodes // [])) as $raw
      | reduce $raw[] as $it ({acc: [], seen: {}};
          if .seen[$it.url] then .
          else {acc: (.acc + [$it]), seen: (.seen + {($it.url): true})}
          end)
      | .acc
      | sort_by(.updatedAt // "")
      | reverse
      | sort_by(whyRank)
      | .[:8] as $items
      | {
          login: ($owner.login // $login),
          kind: $kind,
          name: ($owner.name // $login),
          short: $short,
          avatarUrl: ($owner.avatarUrl // ""),
          url: ($owner.url // ("https://github.com/" + $login)),
          issues: ($d.issues.issueCount // 0),
          prs: ($d.prs.issueCount // 0),
          nightReady: $night,
          agentReady: $agent,
          parked: ($d.park.issueCount // 0),
          reviewNeeded: $review,
          attention: ($night + $review),
          items: $items
        }
    '
}

owners_json='[]'
errors=()

while IFS=: read -r kind login short; do
  [[ -n $kind ]] || continue
  if ! owner_json=$(fetch_owner "$kind" "$login" "$short" 2>/tmp/github-orgs.err); then
    errors+=("$login")
    owner_json=$(jq -n --arg login "$login" --arg kind "$kind" --arg short "$short" '{
      login: $login, kind: $kind, name: $login, short: $short,
      avatarUrl: "", url: ("https://github.com/" + $login),
      issues: 0, prs: 0, nightReady: 0, agentReady: 0, parked: 0,
      reviewNeeded: 0, attention: 0, items: []
    }')
  fi
  owners_json=$(jq -c --argjson owner "$owner_json" '. + [$owner]' <<<"$owners_json")
done <<'OWNERS'
user:jordanpartridge:JP
org:the-shit:shit
org:conduit-ui:conduit
org:synapse-sentinel:synapse
OWNERS

error=""
if ((${#errors[@]} > 0)); then
  error="failed: ${errors[*]}"
fi

now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
result=$(jq -n \
  --arg updatedAt "$now" \
  --arg error "$error" \
  --argjson orgs "$owners_json" '
    {
      updatedAt: $updatedAt,
      error: (if $error == "" then null else $error end),
      orgs: $orgs,
      attention: ($orgs | map(.attention) | add // 0)
    }
  ')

tmp="${OUT}.tmp.$$"
printf '%s\n' "$result" >"$tmp"
mv "$tmp" "$OUT"
printf '%s\n' "$result"
