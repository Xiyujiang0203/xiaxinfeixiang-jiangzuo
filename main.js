const fs = require('fs')

const BASE = 'http://unify.xmu.edu.cn'
const cookie = 'deviceKey=114755dc-9f85-492f-bec1-7b622010863a'

const formHeaders = {
    Host: 'unify.xmu.edu.cn',
    cookie,
    'content-type': 'application/x-www-form-urlencoded'
}

const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function collectLectureIds(signUpRes, signInRes) {
    const s = new Set()
    for (const row of signUpRes.data || []) {
        const v = row.ActivityCategoryId || row.ActivityId || row.Id
        if (v && uuidRe.test(String(v))) s.add(String(v))
    }
    for (const row of signInRes.data || []) {
        const v = row.ActivityCategoryId || row.ActivityId || row.Id
        if (v && uuidRe.test(String(v))) s.add(String(v))
    }
    for (const id of signUpRes.delay?.miss || []) {
        if (id && uuidRe.test(String(id))) s.add(String(id))
    }
    for (const id of signInRes.delay?.miss || []) {
        if (id && uuidRe.test(String(id))) s.add(String(id))
    }
    return [...s].sort()
}

async function main() {
    const lectureText = await fetch(`${BASE}/mob/iuc/lecture/myLecture`, {
        method: 'GET',
        headers: { Host: 'unify.xmu.edu.cn', cookie }
    }).then((r) => r.text())

    const basicConfig = await fetch(`${BASE}/api/config/GetBasicConfig`, {
        method: 'POST',
        headers: formHeaders,
        body: ''
    }).then((r) => r.json())

    const signUpRes = await fetch(`${BASE}/api/activity/MySignUp`, {
        method: 'POST',
        headers: formHeaders,
        body: 'page=1&pageSize=100'
    }).then((r) => r.json())

    const signInRes = await fetch(`${BASE}/api/activity/MySignIn`, {
        method: 'POST',
        headers: formHeaders,
        body: 'page=1&pageSize=100'
    }).then((r) => r.json())

    const ids = collectLectureIds(signUpRes, signInRes)
    const detailParts = await Promise.all(
        ids.map(async (id) => {
            const detail = await fetch(`${BASE}/api/activity/GetUserActivityCategory`, {
                method: 'POST',
                headers: formHeaders,
                body: `id=${encodeURIComponent(id)}&deviceKey=`
            }).then((r) => r.json())
            return `\n\n=== GetUserActivityCategory?id=${id} ===\n${JSON.stringify(detail, null, 2)}`
        })
    )

    const parts = [
        '=== /mob/iuc/lecture/myLecture ===\n',
        lectureText,
        '\n\n=== /api/config/GetBasicConfig ===\n',
        JSON.stringify(basicConfig, null, 2),
        '\n\n=== /api/activity/MySignUp ===\n',
        JSON.stringify(signUpRes, null, 2),
        '\n\n=== /api/activity/MySignIn ===\n',
        JSON.stringify(signInRes, null, 2),
        ...detailParts
    ]

    fs.writeFileSync('output.txt', parts.join(''))
}

main()
