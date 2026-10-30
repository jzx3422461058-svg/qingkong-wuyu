import Foundation

public enum RegistrationStatus: String, Codable, CaseIterable, Sendable { case unnecessary = "无需报名", pending = "待报名", registered = "已报名" }
public enum AttendanceStatus: String, Codable, CaseIterable, Sendable { case upcoming = "未开始", attended = "已参加", missed = "未参加", cancelled = "已取消" }
public struct ChecklistItem: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var title = ""
    public var done = false
    public init(title: String = "") { self.title = title }
}
public struct Activity: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var title = ""
    public var category = "讲座"
    public var organizer = ""
    public var location = ""
    public var startDate = Day.today()
    public var startTime = "14:00"
    public var endDate = Day.today()
    public var endTime = "16:00"
    public var registration: RegistrationStatus = .unnecessary
    public var registrationDate = ""
    public var registrationTime = "18:00"
    public var attendance: AttendanceStatus = .upcoming
    public var preparation: [ChecklistItem] = []
    public var notes = ""
    public var summary = ""
    public var volunteerHours = ""
    public var link = ""
    public var registrationLead = 1440
    public var eventLead = 60
    public init() {}
    public static let categories = ["讲座", "社团", "比赛", "志愿服务", "学生工作", "其他"]
    public var preparationProgress: String { "\(preparation.filter(\.done).count) / \(preparation.count)" }
    public func validate() throws {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty, !category.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppError("请输入活动名称和类别。") }
        guard Day.date(startDate) != nil, Day.date(endDate) != nil, Day.minutes(startTime) != nil, Day.minutes(endTime) != nil, startDate + startTime < endDate + endTime else { throw AppError("请检查活动起止时间，结束时间必须晚于开始时间。") }
        try Day.validateOptional(registrationDate, name: "报名截止日期")
        guard Day.minutes(registrationTime) != nil else { throw AppError("请填写有效的报名截止时间。") }
        if !registrationDate.isEmpty && registrationDate + registrationTime > startDate + startTime { throw AppError("报名截止时间不能晚于活动开始时间。") }
        try Workspace.unique(preparation.map(\.id))
        guard preparation.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }) else { throw AppError("准备事项不能为空。") }
        try FitnessMath.number(volunteerHours, name: "实际志愿时长", minimum: 0)
        if !link.isEmpty {
            guard let url = URL(string: link), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw AppError("参考链接请填写完整的 http 或 https 地址。") }
        }
        guard (0...10080).contains(registrationLead), (0...10080).contains(eventLead) else { throw AppError("提醒提前时间应在 0—10080 分钟内。") }
    }
    public static func attendedHours(_ activities: [Activity]) -> Double {
        activities.filter { $0.attendance == .attended && $0.category == "志愿服务" }.compactMap { Double($0.volunteerHours) }.reduce(0, +)
    }
}
