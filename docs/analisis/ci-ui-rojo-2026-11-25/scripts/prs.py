import json,subprocess
Q='''query($c:String){repository(owner:"jur211296",name:"Yala"){pullRequests(first:20,after:$c,orderBy:{field:CREATED_AT,direction:DESC}){pageInfo{hasNextPage endCursor}
nodes{number title createdAt mergedAt closedAt state baseRefName headRefName additions deletions changedFiles
commits{totalCount}
timelineItems(first:60,itemTypes:[AUTO_MERGE_ENABLED_EVENT,AUTO_MERGE_DISABLED_EVENT,HEAD_REF_FORCE_PUSHED_EVENT,PULL_REQUEST_COMMIT,MERGED_EVENT]){nodes{__typename ... on AutoMergeEnabledEvent{createdAt} ... on AutoMergeDisabledEvent{createdAt reason} ... on HeadRefForcePushedEvent{createdAt} ... on PullRequestCommit{commit{committedDate pushedDate}} ... on MergedEvent{createdAt}}}
}}}}'''
out=[];c=None
while True:
    a=['gh','api','graphql','-f','query='+Q]+(['-f','c='+c] if c else [])
    import time
    for _ in range(4):
        try:
            r=json.loads(subprocess.check_output(a));break
        except Exception: time.sleep(3)
    r=r['data']['repository']['pullRequests']
    out+=r['nodes']
    if not r['pageInfo']['hasNextPage'] or r['nodes'][-1]['createdAt']<'2026-10-01': break
    c=r['pageInfo']['endCursor']
json.dump(out,open('prs.json','w'))
print(len(out),out[-1]['createdAt'])
