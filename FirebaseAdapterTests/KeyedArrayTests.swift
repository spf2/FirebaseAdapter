//
//  KeyedArray.swift
//  FirebaseAdapter
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Steve Farrell. All rights reserved.
//

import FirebaseAdapter
import XCTest

class TestKeyedObject : KeyedObject {
    static let a = TestKeyedObject("a")
    static let b = TestKeyedObject("b")
    static let c = TestKeyedObject("c")
    
    var key: String?
    
    init(_ key: String) {
        self.key = key
    }
}

class KeyedArrayTests: XCTestCase {
    var testArray = KeyedArray<TestKeyedObject>()

    func testKeyedArrayAppend() {
        testArray.append(TestKeyedObject.a)
        testArray.append(TestKeyedObject.b)
        testArray.append(TestKeyedObject.c)
        XCTAssertEqual(0, testArray.find(TestKeyedObject.a.key!)!)
        XCTAssertEqual(1, testArray.find(TestKeyedObject.b.key!)!)
        XCTAssertEqual(2, testArray.find(TestKeyedObject.c.key!)!)
    }
    
    func testKeyedArrayInsert() {
        testArray.insert(TestKeyedObject.c, atIndex: 0)
        testArray.insert(TestKeyedObject.b, atIndex: 0)
        testArray.insert(TestKeyedObject.a, atIndex: 0)
        XCTAssertEqual(0, testArray.find(TestKeyedObject.a.key!)!)
        XCTAssertEqual(1, testArray.find(TestKeyedObject.b.key!)!)
        XCTAssertEqual(2, testArray.find(TestKeyedObject.c.key!)!)
    }
    
    func testKeyedArrayRemove() {
        testArray.append(TestKeyedObject.a)
        testArray.append(TestKeyedObject.b)
        testArray.append(TestKeyedObject.c)
        testArray.removeAtIndex(0)
        XCTAssertEqual(0, testArray.find(TestKeyedObject.b.key!)!)
        XCTAssertEqual(1, testArray.find(TestKeyedObject.c.key!)!)
    }
}
