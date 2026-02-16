*** Settings ***
Library           RequestsLibrary
Library           OperatingSystem
Library           Collections
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite

*** Variables ***
${DEVICE_IP}      None
${BASE_URL}       None
${SESSION}        d1session

*** Keywords ***
Setup Suite
    ${DEVICE_IP}=    Get Environment Variable    DEVICE_IP    192.168.1.107
    Set Suite Variable    ${DEVICE_IP}
    ${BASE_URL}=    Set Variable    http://${DEVICE_IP}
    Set Suite Variable    ${BASE_URL}
    Log    Starting ESP8266 D1 Control API tests
    Create Session    ${SESSION}    ${BASE_URL}

Teardown Suite
    Log    Test suite finished

*** Test Cases ***
Power On And WiFi
    [Tags]    firmware
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.status_code}    200
    Dictionary Should Contain Key    ${resp.json()}    d1

POST On Sets D1 High
    [Tags]    api
    POST On Session    ${SESSION}    /api/on
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    1

POST Off Sets D1 Low
    [Tags]    api
    # Reset latch and D1 state
    POST On Session    ${SESSION}    /api/reset
    Sleep    0.5s
    ${before}=  GET On Session    ${SESSION}    /api/status
    # Wait for latch to be released
    FOR    ${i}    IN RANGE    20
        ${latch}=    Set Variable    ${before.json()['latch']}
        Exit For Loop If    ${latch} == 0 or ${latch} == None
        Sleep    0.5s
        ${before}=  GET On Session    ${SESSION}    /api/status
    END
    # Now turn off
    POST On Session    ${SESSION}    /api/off
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0

POST Toggle Flips D1
    [Tags]    api
    # Reset latch and D1 state
    POST On Session    ${SESSION}    /api/reset
    Sleep    0.5s
    ${before}=  GET On Session    ${SESSION}    /api/status
    ${prev}=    Set Variable    ${before.json()['d1']}
    # Wait for latch to be released
    FOR    ${i}    IN RANGE    20
        ${latch}=    Set Variable    ${before.json()['latch']}
        Exit For Loop If    ${latch} == 0 or ${latch} == None
        Sleep    0.5s
        ${before}=  GET On Session    ${SESSION}    /api/status
    END
    # Now toggle
    POST On Session    ${SESSION}    /api/toggle
    Sleep    0.5s
    ${after}=  GET On Session    ${SESSION}    /api/status
    Should Not Be Equal    ${after.json()['d1']}    ${prev}

Menu Endpoint Returns Status
    [Tags]    api
    ${resp}=  GET On Session    ${SESSION}    /menu
    Should Contain    ${resp.text}    ESP8266 Status

Latch ON Reverts After Period
    [Tags]    latch
    ${body}=    Create Dictionary    latch=2
    POST On Session    ${SESSION}    /api/latch    json=${body}
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/off
    Sleep    1.0s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0
    POST On Session    ${SESSION}    /api/on
    Sleep    1.0s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    1
    Sleep    3.0s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0

Latch Disabled (0) Does Not Revert
    [Tags]    latch
    ${body}=    Create Dictionary    latch=0
    ${resp}=  POST On Session    ${SESSION}    /api/latch    json=${body}
    Should Be True    ${resp.json()['latch']} >= 1
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/off
    Sleep    1.0s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0
    POST On Session    ${SESSION}    /api/on
    Sleep    1.0s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    1
    Sleep    3.0s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0

Latch Rejects State Change During Active Period
    [Tags]    latch    enforcement
    ${body}=    Create Dictionary    latch=2
    POST On Session    ${SESSION}    /api/latch    json=${body}
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/off
    Sleep    1.0s
    POST On Session    ${SESSION}    /api/on
    Sleep    0.5s
    ${resp}=  POST On Session    ${SESSION}    /api/off
    Should Be Equal As Integers    ${resp.status_code}    423
    Should Contain    ${resp.text}    Latch active
    Sleep    3.0s
    ${resp}=  POST On Session    ${SESSION}    /api/off
    Should Be Equal As Integers    ${resp.status_code}    200

Default Latch Value On Reset
    [Tags]    latch    default
    Log    Manual: After device reset, GET /api/status should show latch=5

Latch Min/Max Enforced By API
    [Tags]    latch    constraints
    ${body}=    Create Dictionary    latch=0
    ${resp}=  POST On Session    ${SESSION}    /api/latch    json=${body}
    Should Be True    ${resp.json()['latch']} >= 1
    ${body}=    Create Dictionary    latch=9999
    ${resp}=  POST On Session    ${SESSION}    /api/latch    json=${body}
    Should Be True    ${resp.json()['latch']} <= 3600

# Edge Cases
Rapid State Change Requests During Latch
    [Tags]    latch    edge
    ${body}=    Create Dictionary    latch=2
    POST On Session    ${SESSION}    /api/latch    json=${body}
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/off
    Sleep    1.0s
    POST On Session    ${SESSION}    /api/on
    Sleep    0.5s
    ${resp}=  POST On Session    ${SESSION}    /api/on
    Should Be Equal As Integers    ${resp.status_code}    423
    ${resp}=  POST On Session    ${SESSION}    /api/off
    Should Be Equal As Integers    ${resp.status_code}    423
    ${resp}=  POST On Session    ${SESSION}    /api/toggle
    Should Be Equal As Integers    ${resp.status_code}    423
    Sleep    3.0s
    ${resp}=  POST On Session    ${SESSION}    /api/toggle
    Should Be Equal As Integers    ${resp.status_code}    200

Invalid Latch Values Are Handled
    [Tags]    latch    edge    constraints
    ${body}=    Create Dictionary    latch=-5
    ${resp}=  POST On Session    ${SESSION}    /api/latch    json=${body}
    Should Be True    ${resp.json()['latch']} >= 1
    ${body}=    Create Dictionary    latch=abc
    ${resp}=  POST On Session    ${SESSION}    /api/latch    json=${body}
    Should Be True    ${resp.json()['latch']} >= 1

Latch Timer Reset On Expiry
    [Tags]    latch    edge
    ${body}=    Create Dictionary    latch=1
    POST On Session    ${SESSION}    /api/latch    json=${body}
    Sleep    0.2s
    POST On Session    ${SESSION}    /api/off
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/on
    Sleep    1.2s
    ${resp}=  POST On Session    ${SESSION}    /api/on
    Should Be Equal As Integers    ${resp.status_code}    200
