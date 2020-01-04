//
//  TaskRegistry.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation
import Etcetera

final class TaskRegistry<TaskID: Hashable, Result> {

    typealias RequestID = UUID
    typealias Finish = (Result) -> Void
    typealias TaskType = Task<TaskID, Result>
    typealias RequestType = Request<Result>

    private var protectedTasks = Protected<[TaskID: TaskType]>([:])

    func addRequest(taskId: TaskID, workQueue: OperationQueue, taskExecution: @escaping (@escaping Finish) -> Void, taskCancellation: @escaping () -> Void, taskCompletion: @escaping TaskType.Completion, requestCompletion: @escaping RequestType.Completion) -> RequestID {
        let request = RequestType(completion: requestCompletion)
        protectedTasks.access { tasks in
            if var task = tasks[taskId] {
                task.requests[request.id] = request
                tasks[taskId] = task
            } else {
                var task = Task<TaskID, Result>(
                    id: taskId,
                    cancellation: taskCancellation,
                    completion: taskCompletion
                )
                task.requests[request.id] = request
                tasks[taskId] = task
                let finish: Finish = { [weak self] result in
                    onMain { self?.finishTask(withId: taskId, result: result) }
                }
                // `deferred(on:block:)` will dispatch to next main runloop then
                // from there dispatch to a global queue, ensuring that the
                // completion block cannot be executed before this method returns.
                deferred(on: workQueue) { taskExecution(finish) }
            }
        }
        return request.id
    }

    func cancelRequest(withId id: RequestID) {
        let taskCancellation: TaskType.Cancellation? = protectedTasks.access { tasks in
            guard var (_, task) = tasks.first(where: { $0.value.requests[id] != nil }) else { return nil }
            task.requests[id] = nil
            let shouldCancelTask = task.requests.isEmpty
            if shouldCancelTask {
                tasks[task.id] = nil
                return task.cancellation
            } else {
                tasks[task.id] = task
                return nil
            }
        }
        taskCancellation?()
    }

    private func finishTask(withId id: TaskID, result: Result) {
        let (taskCompletion, requestCompletions): (TaskType.Completion?, [RequestType.Completion]?) = protectedTasks.access { tasks in
            let task = tasks[id]
            tasks[id] = nil
            return (task?.completion, task?.requests.values.map { $0.completion })
        }
        // Per my standard habit, completion handlers are always performed on
        // the main queue.
        if let completion = taskCompletion {
            onMain { completion(result) }
        }
        if let completions = requestCompletions {
            onMain {
                completions.forEach { $0(result) }
            }
        }
    }

}
