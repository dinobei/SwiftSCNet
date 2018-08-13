//
//  Queue.swift
//  iSwiftCore
//
//  Created by Jin Wang on 24/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//
import Foundation

// By default, this will be a FIFO queue.
class BlockingQueue<Element> {
    private var dataSource: ConcurrentArray<Element>
    private let dataSemaphore: DispatchSemaphore
    
    init() {
        dataSource = ConcurrentArray<Element>()
        dataSemaphore = DispatchSemaphore(value: 0)
    }
    
    func add(_ e: Element) {
        dataSource.append(e)
        
//        Logger.debug.print("Blocking Queue adding element.")
        
        // New data available.
        dataSemaphore.signal()
    }
    
    func take(_ timeout: TimeInterval? = nil) throws -> Element {
        let t: DispatchTime
        if let timeout = timeout {
            t = DispatchTime.now() + Double(Int64(timeout * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        } else {
            t = DispatchTime.distantFuture
        }
        
        let _ = dataSemaphore.wait(timeout: t)
        
        // This will throw error if there's no element.
        return try dataSource.removeFirst()
    }
    
    func removeAll() {
        dataSource.removeAll()
    }
}

class ConcurrentArray<T> {
    private var dataSource: Array<T>
    
    init() {
        self.dataSource = [T]()
    }
    
    func append(_ element: T) {
        synchronized(self) {
            dataSource.append(element)
        }
    }
    
    func removeLast() -> T {
        return synchronized(self) { () -> T in
            return dataSource.removeLast()
        }
    }
    
    func removeFirst() throws -> T {
        return try synchronized(self) { () -> T in
            if dataSource.isEmpty {
                throw BlockingQueueError.noItem
            }
            return dataSource.removeFirst()
        }
    }
    
    func removeAtIndex(_ index: Int) -> T {
        return synchronized(self) { () -> T in
            return dataSource.remove(at: index)
        }
    }
    
    func removeAll(_ keepCapacity: Bool = false) {
        synchronized(self) {
            dataSource.removeAll(keepingCapacity: keepCapacity)
        }
    }
}

func synchronized<T>(_ lock: AnyObject, closure: () throws -> T) rethrows -> T {
    objc_sync_enter(lock)
    defer {
        objc_sync_exit(lock)
    }
    return try closure()
}

public enum BlockingQueueError: Error {
    case noItem
}
