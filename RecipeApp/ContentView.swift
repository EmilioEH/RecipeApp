import SwiftUI
import UniformTypeIdentifiers

// iOS 14+ Compatible Recipe App - Individual File Storage

// MARK: - Data Models
struct Recipe: Identifiable, Codable {
    let id: UUID
    var name: String
    var ingredients: [String]
    var instructions: String
    var prepTime: Int
    var cookTime: Int
    var servings: Int
    var category: RecipeCategory
    var notes: String
    var rating: Double
    var lastModified: Date
    var lastModifiedBy: String
    var imageFileName: String? // Reference to image file in same folder
    
    var totalTime: Int {
        prepTime + cookTime
    }
    
    init(name: String, ingredients: [String], instructions: String, prepTime: Int, cookTime: Int, servings: Int, category: RecipeCategory, notes: String = "", rating: Double = 0) {
        self.id = UUID()
        self.name = name
        self.ingredients = ingredients
        self.instructions = instructions
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.category = category
        self.notes = notes
        self.rating = rating
        self.lastModified = Date()
        self.lastModifiedBy = UIDevice.current.name
        self.imageFileName = nil
    }
    
    // Helper to parse ingredients for grocery list
    var parsedIngredients: [Ingredient] {
        ingredients.map { Ingredient(from: $0) }
    }
    
    // Generate a safe filename from the recipe name
    var fileName: String {
        let safeName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "*", with: "-")
            .replacingOccurrences(of: "?", with: "-")
            .replacingOccurrences(of: "\"", with: "-")
            .replacingOccurrences(of: "<", with: "-")
            .replacingOccurrences(of: ">", with: "-")
            .replacingOccurrences(of: "|", with: "-")
            .trimmingCharacters(in: .whitespaces)
        
        return "\(safeName)_\(id.uuidString).json"
    }
}

enum RecipeCategory: String, CaseIterable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case dessert = "Dessert"
    case snack = "Snack"
    case beverage = "Beverage"
    
    var icon: String {
        switch self {
        case .breakfast: return "sun.max.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.fill"
        case .dessert: return "birthday.cake.fill"
        case .snack: return "carrot.fill"
        case .beverage: return "cup.and.saucer.fill"
        }
    }
}

// MARK: - Grocery List Data Models
// Add these new models after the existing Recipe model

struct Ingredient: Codable, Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unit: String
    var category: GroceryCategory
    
    // Parse ingredient string like "2 cups flour" into components
    init(from string: String) {
        let components = string.split(separator: " ", maxSplits: 2)
        
        if components.count >= 3 {
            // Try to parse quantity
            if let qty = Double(components[0]) {
                self.quantity = qty
                self.unit = String(components[1])
                self.name = String(components[2])
            } else if components.count >= 2, let qty = Double(String(components[0]) + String(components[1])) {
                // Handle fractions like "1 1/2"
                self.quantity = qty
                self.unit = components.count > 2 ? String(components[2]) : ""
                self.name = components.count > 3 ? components[3...].joined(separator: " ") : ""
            } else {
                // No quantity found
                self.quantity = 1
                self.unit = ""
                self.name = string
            }
        } else if components.count == 2 {
            if let qty = Double(components[0]) {
                self.quantity = qty
                self.unit = ""
                self.name = String(components[1])
            } else {
                self.quantity = 1
                self.unit = ""
                self.name = string
            }
        } else {
            self.quantity = 1
            self.unit = ""
            self.name = string
        }
        
        // Auto-categorize based on common ingredients
        self.category = GroceryCategory.autoCategory(for: self.name)
    }
    
    init(name: String, quantity: Double, unit: String, category: GroceryCategory) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
    }
}

enum GroceryCategory: String, CaseIterable, Codable {
    case produce = "Produce"
    case dairy = "Dairy"
    case meat = "Meat & Seafood"
    case pantry = "Pantry"
    case bakery = "Bakery"
    case frozen = "Frozen"
    case beverages = "Beverages"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .produce: return "leaf"
        case .dairy: return "drop"
        case .meat: return "fish"
        case .pantry: return "cabinet"
        case .bakery: return "text.badge.star"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer"
        case .other: return "cart"
        }
    }
    
    static func autoCategory(for ingredient: String) -> GroceryCategory {
        let lowercased = ingredient.lowercased()
        
        // Produce keywords
        let produceKeywords = ["lettuce", "tomato", "onion", "garlic", "carrot", "celery", "potato", "apple", "banana", "orange", "lemon", "lime", "pepper", "cucumber", "spinach", "kale", "broccoli", "cauliflower"]
        
        // Dairy keywords
        let dairyKeywords = ["milk", "cream", "cheese", "yogurt", "butter", "sour cream", "cottage cheese", "mozzarella", "cheddar", "parmesan"]
        
        // Meat keywords
        let meatKeywords = ["chicken", "beef", "pork", "fish", "salmon", "shrimp", "bacon", "sausage", "ground", "steak", "turkey", "ham"]
        
        // Pantry keywords
        let pantryKeywords = ["flour", "sugar", "salt", "pepper", "oil", "vinegar", "rice", "pasta", "beans", "sauce", "spice", "seasoning", "baking powder", "baking soda"]
        
        // Bakery keywords
        let bakeryKeywords = ["bread", "rolls", "bagel", "muffin", "croissant", "tortilla", "pita"]
        
        // Check each category
        if produceKeywords.contains(where: { lowercased.contains($0) }) {
            return .produce
        } else if dairyKeywords.contains(where: { lowercased.contains($0) }) {
            return .dairy
        } else if meatKeywords.contains(where: { lowercased.contains($0) }) {
            return .meat
        } else if pantryKeywords.contains(where: { lowercased.contains($0) }) {
            return .pantry
        } else if bakeryKeywords.contains(where: { lowercased.contains($0) }) {
            return .bakery
        }
        
        return .other
    }
}

struct GroceryItem: Identifiable {
    let id = UUID()
    var ingredient: Ingredient
    var isChecked: Bool = false
    var alreadyHave: Bool = false
    var fromRecipes: [String] = [] // Track which recipes this came from
    
    var displayText: String {
        if ingredient.quantity > 0 && !ingredient.unit.isEmpty {
            return "\(formatQuantity(ingredient.quantity)) \(ingredient.unit) \(ingredient.name)"
        } else if ingredient.quantity > 0 {
            return "\(formatQuantity(ingredient.quantity)) \(ingredient.name)"
        } else {
            return ingredient.name
        }
    }
    
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(quantity))
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

enum GrocerySortOption: String, CaseIterable {
    case category = "By Category"
    case alphabetical = "Alphabetical"
    case recipe = "By Recipe"
    
    var icon: String {
        switch self {
        case .category: return "square.grid.2x2"
        case .alphabetical: return "textformat.abc"
        case .recipe: return "book"
        }
    }
}

// MARK: - Grocery List View
struct GroceryListView: View {
    let selectedRecipes: [Recipe]
    @State private var groceryItems: [GroceryItem] = []
    @State private var sortOption: GrocerySortOption = .category
    @State private var showingAddItem = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var editMode: EditMode = .inactive
    @Environment(\.dismiss) var dismiss
    
    var sortedItems: [GroceryItem] {
        switch sortOption {
        case .category:
            return groceryItems.sorted { item1, item2 in
                if item1.ingredient.category.rawValue != item2.ingredient.category.rawValue {
                    return item1.ingredient.category.rawValue < item2.ingredient.category.rawValue
                }
                return item1.ingredient.name < item2.ingredient.name
            }
        case .alphabetical:
            return groceryItems.sorted { $0.ingredient.name < $1.ingredient.name }
        case .recipe:
            return groceryItems.sorted { item1, item2 in
                let recipe1 = item1.fromRecipes.first ?? ""
                let recipe2 = item2.fromRecipes.first ?? ""
                if recipe1 != recipe2 {
                    return recipe1 < recipe2
                }
                return item1.ingredient.name < item2.ingredient.name
            }
        }
    }
    
    var itemsByCategory: [(GroceryCategory, [GroceryItem])] {
        Dictionary(grouping: sortedItems) { $0.ingredient.category }
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value) }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Summary header
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(groceryItems.filter { !$0.alreadyHave }.count) items to buy")
                            .font(.headline)
                        Text("From \(selectedRecipes.count) recipes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Sort picker
                    Menu {
                        ForEach(GrocerySortOption.allCases, id: \.self) { option in
                            Button(action: { sortOption = option }) {
                                Label(option.rawValue, systemImage: option.icon)
                            }
                        }
                    } label: {
                        Label(sortOption.rawValue, systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                List {
                    if sortOption == .category {
                        ForEach(itemsByCategory, id: \.0) { category, items in
                            Section(header: HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(.blue)
                                Text(category.rawValue)
                                    .fontWeight(.semibold)
                            }) {
                                ForEach(items) { item in
                                    GroceryItemRow(item: binding(for: item))
                                }
                                .onDelete { indexSet in
                                    deleteItems(from: items, at: indexSet)
                                }
                            }
                        }
                    } else {
                        ForEach(sortedItems) { item in
                            GroceryItemRow(item: binding(for: item))
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .environment(\.editMode, $editMode)
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        EditButton()
                        
                        Menu {
                            Button(action: { showingAddItem = true }) {
                                Label("Add Item", systemImage: "plus")
                            }
                            
                            Divider()
                            
                            Button(action: shareAsText) {
                                Label("Share as Text", systemImage: "doc.text")
                            }
                            
                            Button(action: copyToClipboard) {
                                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: printList) {
                                Label("Print", systemImage: "printer")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                generateGroceryList()
            }
            .sheet(isPresented: $showingAddItem) {
                AddGroceryItemView { newItem in
                    groceryItems.append(GroceryItem(ingredient: newItem))
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func binding(for item: GroceryItem) -> Binding<GroceryItem> {
        guard let index = groceryItems.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $groceryItems[index]
    }
    
    private func deleteItems(at offsets: IndexSet) {
        groceryItems.remove(atOffsets: offsets)
    }
    
    private func deleteItems(from items: [GroceryItem], at offsets: IndexSet) {
        for index in offsets {
            if let itemIndex = groceryItems.firstIndex(where: { $0.id == items[index].id }) {
                groceryItems.remove(at: itemIndex)
            }
        }
    }
    
    private func generateGroceryList() {
        var ingredientMap: [String: GroceryItem] = [:]
        
        for recipe in selectedRecipes {
            for ingredientString in recipe.ingredients {
                let ingredient = Ingredient(from: ingredientString)
                let key = "\(ingredient.name.lowercased())-\(ingredient.unit.lowercased())"
                
                if var existingItem = ingredientMap[key] {
                    // Combine quantities
                    existingItem.ingredient.quantity += ingredient.quantity
                    existingItem.fromRecipes.append(recipe.name)
                    ingredientMap[key] = existingItem
                } else {
                    // New item
                    let groceryItem = GroceryItem(
                        ingredient: ingredient,
                        fromRecipes: [recipe.name]
                    )
                    ingredientMap[key] = groceryItem
                }
            }
        }
        
        groceryItems = Array(ingredientMap.values)
    }
    
    private func shareAsText() {
        var text = "Shopping List\n"
        text += String(repeating: "=", count: 13) + "\n\n"
        
        if sortOption == .category {
            for (category, items) in itemsByCategory {
                text += "\(category.rawValue)\n"
                text += String(repeating: "-", count: category.rawValue.count) + "\n"
                for item in items where !item.alreadyHave {
                    text += "□ \(item.displayText)\n"
                }
                text += "\n"
            }
        } else {
            for item in sortedItems where !item.alreadyHave {
                text += "□ \(item.displayText)\n"
            }
        }
        
        text += "\n───────────────────────\n"
        text += "Generated from \(selectedRecipes.count) recipes"
        
        shareItems = [text]
        showingShareSheet = true
    }
    
    private func copyToClipboard() {
        var text = ""
        for item in sortedItems where !item.alreadyHave {
            text += "• \(item.displayText)\n"
        }
        UIPasteboard.general.string = text
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func printList() {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Shopping List"
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        
        var html = """
        <html>
        <head>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; }
                h1 { color: #333; }
                h2 { color: #666; font-size: 18px; margin-top: 20px; }
                ul { list-style-type: none; padding-left: 0; }
                li { margin: 8px 0; padding-left: 25px; position: relative; }
                li:before { content: "☐"; position: absolute; left: 0; font-size: 18px; }
                .header { color: #888; font-size: 14px; margin-bottom: 20px; }
            </style>
        </head>
        <body>
            <h1>Shopping List</h1>
            <p class="header">Generated from \(selectedRecipes.count) recipes</p>
        """
        
        if sortOption == .category {
            for (category, items) in itemsByCategory {
                html += "<h2>\(category.rawValue)</h2><ul>"
                for item in items where !item.alreadyHave {
                    html += "<li>\(item.displayText)</li>"
                }
                html += "</ul>"
            }
        } else {
            html += "<ul>"
            for item in sortedItems where !item.alreadyHave {
                html += "<li>\(item.displayText)</li>"
            }
            html += "</ul>"
        }
        
        html += "</body></html>"
        
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        printController.printFormatter = formatter
        printController.present(animated: true)
    }
}

// MARK: - Grocery Item Row
struct GroceryItemRow: View {
    @Binding var item: GroceryItem
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            // Check/uncheck button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    item.isChecked.toggle()
                }
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isChecked ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayText)
                    .strikethrough(item.isChecked || item.alreadyHave)
                    .foregroundColor(item.alreadyHave ? .gray : .primary)
                
                if !item.fromRecipes.isEmpty {
                    Text("For: \(item.fromRecipes.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Already have toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    item.alreadyHave.toggle()
                }
            }) {
                Text(item.alreadyHave ? "Have" : "Need")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(item.alreadyHave ? .green : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.alreadyHave ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(15)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(action: { isEditing = true }) {
                Label("Edit Quantity", systemImage: "pencil")
            }
            
            Button(action: {
                item.alreadyHave.toggle()
            }) {
                Label(item.alreadyHave ? "Mark as Needed" : "Mark as Have",
                      systemImage: item.alreadyHave ? "cart.badge.plus" : "house")
            }
        }
        .sheet(isPresented: $isEditing) {
            EditGroceryItemView(item: $item)
        }
    }
}

// MARK: - Add Grocery Item View
struct AddGroceryItemView: View {
    let onAdd: (Ingredient) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var quantity = "1"
    @State private var unit = ""
    @State private var category = GroceryCategory.other
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $name)
                    
                    HStack {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        
                        TextField("Unit (optional)", text: $unit)
                            .placeholder(when: unit.isEmpty) {
                                Text("cups, lbs, etc.")
                                    .foregroundColor(.gray)
                            }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(GroceryCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let qty = Double(quantity) ?? 1
                        let ingredient = Ingredient(
                            name: name,
                            quantity: qty,
                            unit: unit,
                            category: category
                        )
                        onAdd(ingredient)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Grocery Item View
struct EditGroceryItemView: View {
    @Binding var item: GroceryItem
    @Environment(\.dismiss) var dismiss
    
    @State private var quantity: String
    @State private var unit: String
    
    init(item: Binding<GroceryItem>) {
        self._item = item
        self._quantity = State(initialValue: String(format: "%.1f", item.wrappedValue.ingredient.quantity))
        self._unit = State(initialValue: item.wrappedValue.ingredient.unit)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Edit Quantity") {
                    HStack {
                        Text(item.ingredient.name)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        
                        TextField("Unit", text: $unit)
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let qty = Double(quantity) {
                            item.ingredient.quantity = qty
                            item.ingredient.unit = unit
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - View Extension for Placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Storage Manager
class RecipeStorageManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var storageURL: URL?
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "RecipeStorageURL"
    private let recipeExtension = "json"
    private var fileMonitor: DispatchSourceFileSystemObject?
    
    init() {
        loadStorageURL()
        if storageURL != nil {
            loadRecipes()
            startMonitoringFolder()
        }
    }
    
    deinit {
        fileMonitor?.cancel()
    }
    
    private func loadStorageURL() {
        if let bookmarkData = userDefaults.data(forKey: storageKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                if !isStale {
                    storageURL = url
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
    }
    
    func selectStorageFolder(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil)
            userDefaults.set(bookmarkData, forKey: storageKey)
            storageURL = url
            loadRecipes()
            startMonitoringFolder()
        } catch {
            lastError = "Failed to save storage location: \(error.localizedDescription)"
        }
    }
    
    private func startMonitoringFolder() {
        guard let folderURL = storageURL else { return }
        
        fileMonitor?.cancel()
        
        let fileDescriptor = open(folderURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )
        
        source.setEventHandler { [weak self] in
            self?.loadRecipes()
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        fileMonitor = source
    }
    
    func loadRecipes() {
        guard let folderURL = storageURL else { return }
        
        isLoading = true
        lastError = nil
        
        do {
            // Access the security-scoped resource
            _ = folderURL.startAccessingSecurityScopedResource()
            defer { folderURL.stopAccessingSecurityScopedResource() }
            
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            var loadedRecipes: [Recipe] = []
            
            for fileURL in contents {
                if fileURL.pathExtension == recipeExtension {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                        loadedRecipes.append(recipe)
                    } catch {
                        print("Failed to load recipe from \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }
            
            // Sort by most recently modified
            self.recipes = loadedRecipes.sorted { $0.lastModified > $1.lastModified }
            
            // Create sample recipes if folder is empty
            if recipes.isEmpty && contents.filter({ $0.pathExtension == recipeExtension }).isEmpty {
                createSampleRecipes()
            }
        } catch {
            lastError = "Failed to load recipes: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func saveRecipe(_ recipe: Recipe) {
        guard let folderURL = storageURL else { return }
        
        do {
            // Access the security-scoped resource
            _ = folderURL.startAccessingSecurityScopedResource()
            defer { folderURL.stopAccessingSecurityScopedResource() }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recipe)
            
            let fileURL = folderURL.appendingPathComponent(recipe.fileName)
            try data.write(to: fileURL)
            
            // Update local array
            if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
                recipes[index] = recipe
            } else {
                recipes.append(recipe)
            }
            
            // Sort by most recently modified
            recipes.sort { $0.lastModified > $1.lastModified }
        } catch {
            lastError = "Failed to save recipe: \(error.localizedDescription)"
        }
    }
    
    func addRecipe(_ recipe: Recipe) {
        var newRecipe = recipe
        newRecipe.lastModified = Date()
        newRecipe.lastModifiedBy = UIDevice.current.name
        saveRecipe(newRecipe)
    }
    
    func updateRecipe(_ recipe: Recipe) {
        // Delete old file if name changed
        if let existingRecipe = recipes.first(where: { $0.id == recipe.id }),
           existingRecipe.fileName != recipe.fileName {
            deleteRecipeFile(existingRecipe)
        }
        
        var updatedRecipe = recipe
        updatedRecipe.lastModified = Date()
        updatedRecipe.lastModifiedBy = UIDevice.current.name
        saveRecipe(updatedRecipe)
    }
    
    func deleteRecipe(_ recipe: Recipe) {
        deleteRecipeFile(recipe)
        recipes.removeAll { $0.id == recipe.id }
    }
    
    func deleteRecipe(at offsets: IndexSet) {
        for index in offsets {
            deleteRecipe(recipes[index])
        }
    }
    
    private func deleteRecipeFile(_ recipe: Recipe) {
        guard let folderURL = storageURL else { return }
        
        do {
            _ = folderURL.startAccessingSecurityScopedResource()
            defer { folderURL.stopAccessingSecurityScopedResource() }
            
            let fileURL = folderURL.appendingPathComponent(recipe.fileName)
            try FileManager.default.removeItem(at: fileURL)
            
            // Also delete associated image if exists
            if let imageFileName = recipe.imageFileName {
                let imageURL = folderURL.appendingPathComponent(imageFileName)
                try? FileManager.default.removeItem(at: imageURL)
            }
        } catch {
            print("Failed to delete recipe file: \(error)")
        }
    }
    
    private func createSampleRecipes() {
        let sampleRecipes = [
            Recipe(
                name: "Classic Pancakes",
                ingredients: ["2 cups flour", "2 eggs", "1.5 cups milk", "2 tbsp sugar", "2 tsp baking powder", "1/2 tsp salt", "2 tbsp melted butter"],
                instructions: "1. Mix dry ingredients in a bowl\n2. Whisk wet ingredients separately\n3. Combine and mix until just blended\n4. Cook on griddle until bubbles form\n5. Flip and cook until golden",
                prepTime: 10,
                cookTime: 15,
                servings: 4,
                category: .breakfast,
                notes: "For fluffier pancakes, let the batter rest for 5 minutes before cooking. You can also add blueberries or chocolate chips!",
                rating: 5
            ),
            Recipe(
                name: "Caesar Salad",
                ingredients: ["1 head romaine lettuce", "1/2 cup Caesar dressing", "1/4 cup parmesan cheese", "1 cup croutons", "2 tbsp lemon juice"],
                instructions: "1. Wash and chop lettuce\n2. Toss with dressing\n3. Add parmesan and croutons\n4. Squeeze lemon juice on top\n5. Serve immediately",
                prepTime: 15,
                cookTime: 0,
                servings: 2,
                category: .lunch,
                notes: "",
                rating: 4
            ),
            Recipe(
                name: "Spaghetti Carbonara",
                ingredients: ["1 lb spaghetti", "4 eggs", "1 cup parmesan", "8 oz pancetta", "Black pepper", "Salt"],
                instructions: "1. Cook spaghetti al dente\n2. Fry pancetta until crispy\n3. Beat eggs with cheese\n4. Toss hot pasta with pancetta\n5. Remove from heat, add egg mixture\n6. Season with pepper",
                prepTime: 10,
                cookTime: 20,
                servings: 4,
                category: .dinner,
                notes: "The key is to work quickly and keep the pasta hot, but remove from direct heat when adding eggs to avoid scrambling them.",
                rating: 5
            )
        ]
        
        for recipe in sampleRecipes {
            addRecipe(recipe)
        }
    }
    
    func exportAllRecipes() -> URL? {
        guard let folderURL = storageURL else { return nil }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            let exportData = ["recipes": recipes, "exportDate": Date()] as [String : Any]
            let data = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            
            let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("recipes_export_\(Date().timeIntervalSince1970).json")
            try data.write(to: exportURL)
            
            return exportURL
        } catch {
            print("Failed to export recipes: \(error)")
            return nil
        }
    }
}

// MARK: - Recipe Sharing Extension
extension Recipe {
    var shareableText: String {
        var text = "\(name)\n"
        text += String(repeating: "=", count: name.count) + "\n\n"
        
        if rating > 0 {
            text += "Rating: " + String(repeating: "★", count: Int(rating)) + String(repeating: "☆", count: 5 - Int(rating)) + "\n"
        }
        
        text += """
        Category: \(category.rawValue)
        Prep Time: \(prepTime) minutes
        Cook Time: \(cookTime) minutes
        Total Time: \(totalTime) minutes
        Servings: \(servings)
        
        INGREDIENTS
        -----------
        """
        
        for ingredient in ingredients {
            text += "\n• \(ingredient)"
        }
        
        text += "\n\nINSTRUCTIONS\n"
        text += "-----------\n"
        text += instructions
        
        if !notes.isEmpty {
            text += "\n\nNOTES\n"
            text += "-----\n"
            text += notes
        }
        
        text += "\n\n───────────────────────\n"
        text += "Shared from My Recipe App"
        
        return text
    }
    
    func generatePDF() -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Recipe App",
            kCGPDFContextAuthor: lastModifiedBy,
            kCGPDFContextTitle: name
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
            
            let margin: CGFloat = 50
            var yPosition: CGFloat = margin
            
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let headingFont = UIFont.boldSystemFont(ofSize: 16)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineBreakMode = .byWordWrapping
            
            // Draw title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .paragraphStyle: paragraphStyle
            ]
            
            name.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Draw metadata
            let metadataAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.darkGray
            ]
            
            let metadata = "Category: \(category.rawValue) | Prep: \(prepTime) min | Cook: \(cookTime) min | Servings: \(servings)"
            metadata.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metadataAttributes)
            yPosition += 30
            
            // Continue with rest of PDF generation...
        }
        
        return data
    }
}

// MARK: - Main App
@main
struct RecipeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Star Rating View
struct StarRatingView: View {
    @Binding var rating: Double
    var interactive: Bool = true
    var starSize: CGFloat = 20
    var showEmptyStars: Bool = true
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starType(for: star))
                    .font(.system(size: starSize))
                    .foregroundColor(Double(star) <= rating ? .yellow : Color.gray.opacity(showEmptyStars ? 0.3 : 0))
                    .onTapGesture {
                        if interactive {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if rating == Double(star) {
                                    rating = 0
                                } else {
                                    rating = Double(star)
                                }
                            }
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
            }
        }
    }
    
    func starType(for star: Int) -> String {
        if Double(star) <= rating {
            return "star.fill"
        } else {
            return "star"
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var storageManager = RecipeStorageManager()
    @State private var showingAddRecipe = false
    @State private var showingFolderPicker = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .recent
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isInPlanningMode = false
    @State private var selectedRecipeIDs: Set<UUID> = []
    @State private var showingPlanningSheet = false
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case rating = "Rating"
        case recent = "Recently Modified"
        case favorites = "Favorites First"
        
        var systemImage: String {
            switch self {
            case .name: return "textformat"
            case .rating: return "star"
            case .recent: return "clock"
            case .favorites: return "heart"
            }
        }
    }
    
    var selectedRecipesCount: Int {
        selectedRecipeIDs.count
    }
    
    var filteredRecipes: [Recipe] {
        let filtered = searchText.isEmpty ? storageManager.recipes : storageManager.recipes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
        
        switch sortOption {
        case .name:
            return filtered.sorted { $0.name < $1.name }
        case .rating:
            return filtered.sorted { $0.rating > $1.rating }
        case .recent:
            return filtered.sorted { $0.lastModified > $1.lastModified }
        case .favorites:
            return filtered.sorted {
                if $0.rating == 5 && $1.rating != 5 {
                    return true
                } else if $0.rating != 5 && $1.rating == 5 {
                    return false
                } else {
                    return $0.lastModified > $1.lastModified
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if storageManager.storageURL == nil {
                    StorageSetupView(showingFolderPicker: $showingFolderPicker)
                } else {
                    VStack(spacing: 0) {
                        // Custom search bar for iOS 14 compatibility
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search recipes...", text: $searchText)
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Sort indicator
                        if sortOption != .recent {
                            HStack {
                                Image(systemName: sortOption.systemImage)
                                    .font(.caption)
                                Text("Sorted by \(sortOption.rawValue)")
                                    .font(.caption)
                                Spacer()
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        }
                        
                        if storageManager.recipes.isEmpty && !storageManager.isLoading {
                            VStack(spacing: 20) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No Recipes Yet")
                                    .font(.title2)
                                Text("Tap + to create your first recipe")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(filteredRecipes) { recipe in
                                    HStack {
                                        if isInPlanningMode {
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if selectedRecipeIDs.contains(recipe.id) {
                                                        selectedRecipeIDs.remove(recipe.id)
                                                    } else {
                                                        selectedRecipeIDs.insert(recipe.id)
                                                    }
                                                }
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                impactFeedback.impactOccurred()
                                            }) {
                                                Image(systemName: selectedRecipeIDs.contains(recipe.id) ? "checkmark.circle.fill" : "circle")
                                                    .font(.title2)
                                                    .foregroundColor(selectedRecipeIDs.contains(recipe.id) ? .blue : .gray)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        
                                        NavigationLink(destination: RecipeDetailView(recipe: recipe, storageManager: storageManager)) {
                                            RecipeRowView(recipe: recipe)
                                        }
                                        .disabled(isInPlanningMode)
                                    }
                                    .listRowBackground(
                                        selectedRecipeIDs.contains(recipe.id) ? Color.blue.opacity(0.1) : Color.clear
                                    )
                                    .contextMenu {
                                        if !isInPlanningMode {
                                            Button(action: { shareRecipe(recipe) }) {
                                                Label("Share Recipe", systemImage: "square.and.arrow.up")
                                            }
                                            
                                            Button(action: {
                                                UIPasteboard.general.string = recipe.shareableText
                                            }) {
                                                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                            }
                                        }
                                    }
                                }
                                .onDelete(perform: isInPlanningMode ? nil : deleteRecipes)
                            }
                        }
                    }
                    .onAppear {
                        storageManager.loadRecipes()
                    }
                }
            }
            .navigationTitle("My Recipes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if storageManager.storageURL != nil {
                        Menu {
                            Button(action: {
                                withAnimation {
                                    isInPlanningMode = true
                                    selectedRecipeIDs.removeAll()
                                }
                            }) {
                                Label("Plan Weekly Meals", systemImage: "calendar")
                            }
                            
                            Button(action: { storageManager.loadRecipes() }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            
                            Divider()
                            
                            Menu {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button(action: { sortOption = option }) {
                                        Label(option.rawValue, systemImage: option.systemImage)
                                    }
                                }
                            } label: {
                                Label("Sort By", systemImage: "arrow.up.arrow.down")
                            }
                            
                            Divider()
                            
                            Button(action: shareAllRecipes) {
                                Label("Export All Recipes", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: { showingFolderPicker = true }) {
                                Label("Change Storage Folder", systemImage: "folder")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(isInPlanningMode)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if storageManager.storageURL != nil {
                        HStack {
                            if !isInPlanningMode {
                                Button(action: { showingAddRecipe = true }) {
                                    Image(systemName: "plus")
                                }
                            } else {
                                Button("Cancel") {
                                    withAnimation {
                                        isInPlanningMode = false
                                        selectedRecipeIDs.removeAll()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay(
                Group {
                    if isInPlanningMode && selectedRecipeIDs.count > 0 {
                        VStack {
                            Spacer()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(selectedRecipesCount) recipe\(selectedRecipesCount == 1 ? "" : "s") selected")
                                        .font(.headline)
                                    Text("for weekly planning")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showingPlanningSheet = true
                                }) {
                                    Label("Plan Week", systemImage: "calendar.badge.plus")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .cornerRadius(25)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 10)
                            )
                            .padding()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .animation(.spring(), value: isInPlanningMode)
                .animation(.spring(), value: selectedRecipeIDs.count)
            )
            .sheet(isPresented: $showingAddRecipe) {
                AddRecipeView(storageManager: storageManager)
            }
            .sheet(isPresented: $showingFolderPicker) {
                DocumentPicker(storageManager: storageManager)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
            .sheet(isPresented: $showingPlanningSheet) {
                WeeklyPlanningView(
                    selectedRecipeIDs: selectedRecipeIDs,
                    recipes: storageManager.recipes,
                    onComplete: {
                        isInPlanningMode = false
                        selectedRecipeIDs.removeAll()
                    }
                )
            }
        }
    }
    
    func deleteRecipes(at offsets: IndexSet) {
        storageManager.deleteRecipe(at: offsets)
    }
    
    func shareAllRecipes() {
        if let exportURL = storageManager.exportAllRecipes() {
            shareItems = [exportURL]
            showingShareSheet = true
        }
    }
    
    func shareRecipe(_ recipe: Recipe) {
        shareItems = [recipe.shareableText]
        showingShareSheet = true
    }
}

struct StorageSetupView: View {
    @Binding var showingFolderPicker: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Choose Recipe Storage")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Select a folder where your recipes will be stored. Each recipe will be saved as its own file, making it easy to share and backup.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Text("You can use iCloud Drive to sync across devices and share with family.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: { showingFolderPicker = true }) {
                Label("Select Folder", systemImage: "folder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let storageManager: RecipeStorageManager
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access folder")
                return
            }
            
            parent.storageManager.selectStorageFolder(url: url)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct RecipeRowView: View {
    let recipe: Recipe
    
    var body: some View {
        HStack {
            Image(systemName: recipe.category.icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipe.name)
                        .font(.headline)
                    if recipe.rating == 5 {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if recipe.rating > 0 {
                    StarRatingView(rating: .constant(recipe.rating), interactive: false, starSize: 12, showEmptyStars: false)
                }
                
                HStack {
                    Label("\(recipe.totalTime) min", systemImage: "clock")
                    Label("\(recipe.servings)", systemImage: "person.2")
                    if !recipe.notes.isEmpty {
                        Label("Notes", systemImage: "note.text")
                            .foregroundColor(.blue)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Text("Modified \(recipe.lastModified, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    let storageManager: RecipeStorageManager
    @State private var showingEditView = false
    @State private var currentRating: Double
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingCopiedAlert = false
    
    init(recipe: Recipe, storageManager: RecipeStorageManager) {
        self.recipe = recipe
        self.storageManager = storageManager
        self._currentRating = State(initialValue: recipe.rating)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: recipe.category.icon)
                            .font(.title)
                            .foregroundColor(.blue)
                        Text(recipe.category.rawValue)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Rating
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentRating > 0 ? "Your Rating" : "Rate this recipe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        StarRatingView(rating: Binding(
                            get: { currentRating },
                            set: { newValue in
                                currentRating = newValue
                                var updatedRecipe = recipe
                                updatedRecipe.rating = newValue
                                storageManager.updateRecipe(updatedRecipe)
                            }
                        ))
                    }
                    
                    HStack(spacing: 20) {
                        Label("Prep: \(recipe.prepTime) min", systemImage: "timer")
                        Label("Cook: \(recipe.cookTime) min", systemImage: "flame")
                        Label("\(recipe.servings) servings", systemImage: "person.2")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    Text("Last modified by \(recipe.lastModifiedBy) on \(recipe.lastModified, style: .date)")
                        .font(.caption)
                        .foregroundColor(Color.gray.opacity(0.6))
                }
                .padding(.horizontal)
                
                // Ingredients
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.blue)
                                Text(ingredient)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(recipe.instructions)
                        .padding(.horizontal)
                        .lineSpacing(4)
                }
                
                // Notes
                if !recipe.notes.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(.blue)
                            Text("Notes")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        Text(recipe.notes)
                            .padding(.horizontal)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay(
            VStack {
                if showingCopiedAlert {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Recipe copied to clipboard!")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 50)
                }
                Spacer()
            }
            .animation(.easeInOut, value: showingCopiedAlert)
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Menu {
                        Button(action: shareAsText) {
                            Label("Share as Text", systemImage: "doc.text")
                        }
                        
                        Button(action: shareAsPDF) {
                            Label("Share as PDF", systemImage: "doc.richtext")
                        }
                        
                        Button(action: shareAsImage) {
                            Label("Share as Image", systemImage: "photo")
                        }
                        
                        Button(action: shareRecipeFile) {
                            Label("Share JSON File", systemImage: "doc")
                        }
                        
                        Button(action: printRecipe) {
                            Label("Print", systemImage: "printer")
                        }
                        
                        Divider()
                        
                        Button(action: copyToClipboard) {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Button("Edit") {
                        showingEditView = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditRecipeView(recipe: recipe, storageManager: storageManager)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
    }
    
    // MARK: - Share Actions
    func shareAsText() {
        shareItems = [recipe.shareableText]
        showingShareSheet = true
    }
    
    func shareAsPDF() {
        if let pdfData = recipe.generatePDF() {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(recipe.name).pdf")
            do {
                try pdfData.write(to: tempURL)
                shareItems = [tempURL]
                showingShareSheet = true
            } catch {
                print("Failed to create PDF: \(error)")
            }
        }
    }
    
    func shareAsImage() {
        let recipeCard = RecipeCardView(recipe: recipe)
        let image = recipeCard.snapshot()
        shareItems = [image]
        showingShareSheet = true
    }
    
    func shareRecipeFile() {
        guard let folderURL = storageManager.storageURL else { return }
        
        _ = folderURL.startAccessingSecurityScopedResource()
        defer { folderURL.stopAccessingSecurityScopedResource() }
        
        let fileURL = folderURL.appendingPathComponent(recipe.fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            shareItems = [fileURL]
            showingShareSheet = true
        }
    }
    
    func printRecipe() {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = recipe.name
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        
        let formatter = UIMarkupTextPrintFormatter(markupText: """
        <html>
        <head>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; }
                h1 { color: #333; }
                h2 { color: #666; font-size: 18px; margin-top: 20px; }
                .metadata { color: #888; font-size: 14px; }
                ul { padding-left: 20px; }
                li { margin: 5px 0; }
                .instructions { white-space: pre-wrap; }
                .notes { background: #f5f5f5; padding: 10px; border-radius: 5px; margin-top: 20px; }
            </style>
        </head>
        <body>
            <h1>\(recipe.name)</h1>
            <div class="metadata">
                <p>Category: \(recipe.category.rawValue) | Rating: \(recipe.rating > 0 ? String(repeating: "★", count: Int(recipe.rating)) : "Not rated")</p>
                <p>Prep: \(recipe.prepTime) min | Cook: \(recipe.cookTime) min | Servings: \(recipe.servings)</p>
            </div>
            
            <h2>Ingredients</h2>
            <ul>
                \(recipe.ingredients.map { "<li>\($0)</li>" }.joined())
            </ul>
            
            <h2>Instructions</h2>
            <div class="instructions">\(recipe.instructions)</div>
            
            \(recipe.notes.isEmpty ? "" : """
            <div class="notes">
                <h2>Notes</h2>
                <p>\(recipe.notes)</p>
            </div>
            """)
        </body>
        </html>
        """)
        
        printController.printFormatter = formatter
        printController.present(animated: true)
    }
    
    func copyToClipboard() {
        UIPasteboard.general.string = recipe.shareableText
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation {
            showingCopiedAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopiedAlert = false
            }
        }
    }
}

struct AddRecipeView: View {
    @ObservedObject var storageManager: RecipeStorageManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var ingredientText = ""
    @State private var ingredients: [String] = []
    @State private var instructions = ""
    @State private var prepTime = 15
    @State private var cookTime = 30
    @State private var servings = 4
    @State private var category = RecipeCategory.dinner
    @State private var notes = ""
    @State private var rating: Double = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recipe Info") {
                    TextField("Recipe Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Rating")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        StarRatingView(rating: $rating)
                    }
                }
                
                Section("Time & Servings") {
                    Stepper("Prep Time: \(prepTime) min", value: $prepTime, in: 0...120, step: 5)
                    Stepper("Cook Time: \(cookTime) min", value: $cookTime, in: 0...180, step: 5)
                    Stepper("Servings: \(servings)", value: $servings, in: 1...12)
                }
                
                Section("Ingredients") {
                    HStack {
                        TextField("Add ingredient", text: $ingredientText)
                        Button("Add") {
                            if !ingredientText.isEmpty {
                                ingredients.append(ingredientText)
                                ingredientText = ""
                            }
                        }
                        .disabled(ingredientText.isEmpty)
                    }
                    
                    ForEach(ingredients, id: \.self) { ingredient in
                        Text(ingredient)
                    }
                    .onDelete { indexSet in
                        ingredients.remove(atOffsets: indexSet)
                    }
                }
                
                Section("Instructions") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newRecipe = Recipe(
                            name: name,
                            ingredients: ingredients,
                            instructions: instructions,
                            prepTime: prepTime,
                            cookTime: cookTime,
                            servings: servings,
                            category: category,
                            notes: notes,
                            rating: rating
                        )
                        storageManager.addRecipe(newRecipe)
                        dismiss()
                    }
                    .disabled(name.isEmpty || ingredients.isEmpty || instructions.isEmpty)
                }
            }
        }
    }
}

struct EditRecipeView: View {
    let recipe: Recipe
    @ObservedObject var storageManager: RecipeStorageManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var ingredientText = ""
    @State private var ingredients: [String]
    @State private var instructions: String
    @State private var prepTime: Int
    @State private var cookTime: Int
    @State private var servings: Int
    @State private var category: RecipeCategory
    @State private var notes: String
    @State private var rating: Double
    
    init(recipe: Recipe, storageManager: RecipeStorageManager) {
        self.recipe = recipe
        self.storageManager = storageManager
        _name = State(initialValue: recipe.name)
        _ingredients = State(initialValue: recipe.ingredients)
        _instructions = State(initialValue: recipe.instructions)
        _prepTime = State(initialValue: recipe.prepTime)
        _cookTime = State(initialValue: recipe.cookTime)
        _servings = State(initialValue: recipe.servings)
        _category = State(initialValue: recipe.category)
        _notes = State(initialValue: recipe.notes)
        _rating = State(initialValue: recipe.rating)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recipe Info") {
                    TextField("Recipe Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Rating")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        StarRatingView(rating: $rating)
                    }
                }
                
                Section("Time & Servings") {
                    Stepper("Prep Time: \(prepTime) min", value: $prepTime, in: 0...120, step: 5)
                    Stepper("Cook Time: \(cookTime) min", value: $cookTime, in: 0...180, step: 5)
                    Stepper("Servings: \(servings)", value: $servings, in: 1...12)
                }
                
                Section("Ingredients") {
                    HStack {
                        TextField("Add ingredient", text: $ingredientText)
                        Button("Add") {
                            if !ingredientText.isEmpty {
                                ingredients.append(ingredientText)
                                ingredientText = ""
                            }
                        }
                        .disabled(ingredientText.isEmpty)
                    }
                    
                    ForEach(ingredients, id: \.self) { ingredient in
                        Text(ingredient)
                    }
                    .onDelete { indexSet in
                        ingredients.remove(atOffsets: indexSet)
                    }
                }
                
                Section("Instructions") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedRecipe = recipe
                        updatedRecipe.name = name
                        updatedRecipe.ingredients = ingredients
                        updatedRecipe.instructions = instructions
                        updatedRecipe.prepTime = prepTime
                        updatedRecipe.cookTime = cookTime
                        updatedRecipe.servings = servings
                        updatedRecipe.category = category
                        updatedRecipe.notes = notes
                        updatedRecipe.rating = rating
                        
                        storageManager.updateRecipe(updatedRecipe)
                        dismiss()
                    }
                    .disabled(name.isEmpty || ingredients.isEmpty || instructions.isEmpty)
                }
            }
        }
    }
}

// MARK: - Update WeeklyPlanningView
// Replace the existing WeeklyPlanningView with this updated version:

struct WeeklyPlanningView: View {
    let selectedRecipeIDs: Set<UUID>
    let recipes: [Recipe]
    let onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showingGroceryList = false
    
    var selectedRecipes: [Recipe] {
        recipes.filter { selectedRecipeIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary header
                VStack(spacing: 8) {
                    Text("\(selectedRecipes.count) Recipes Selected")
                        .font(.headline)
                    
                    Text("Ready to generate your weekly shopping list")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                
                // Selected recipes list
                List {
                    ForEach(selectedRecipes) { recipe in
                        HStack {
                            Image(systemName: recipe.category.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(recipe.name)
                                    .font(.headline)
                                Text("\(recipe.servings) servings • \(recipe.ingredients.count) ingredients")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        showingGroceryList = true
                    }) {
                        Label("Generate Shopping List", systemImage: "cart.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Back to Selection")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
            .navigationTitle("Weekly Planning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                        onComplete()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingGroceryList) {
                GroceryListView(selectedRecipes: selectedRecipes)
                    .onDisappear {
                        dismiss()
                        onComplete()
                    }
            }
        }
    }
}
// MARK: - Recipe Card View for Image Export
struct RecipeCardView: View {
    let recipe: Recipe
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: recipe.category.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .lineLimit(2)
                        
                        if recipe.rating > 0 {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: Double(star) <= recipe.rating ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Time and servings
                HStack(spacing: 30) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("\(recipe.totalTime) min")
                    }
                    HStack {
                        Image(systemName: "person.2")
                            .foregroundColor(.blue)
                        Text("\(recipe.servings) servings")
                    }
                }
                .font(.subheadline)
                
                Divider()
                
                // Ingredients
                VStack(alignment: .leading, spacing: 8) {
                    Text("INGREDIENTS")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    ForEach(Array(recipe.ingredients.prefix(6).enumerated()), id: \.offset) { index, ingredient in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.blue)
                            Text(ingredient)
                                .font(.caption)
                        }
                    }
                    
                    if recipe.ingredients.count > 6 {
                        Text("+ \(recipe.ingredients.count - 6) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Instructions preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("INSTRUCTIONS")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text(recipe.instructions)
                        .font(.caption)
                        .lineLimit(4)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Footer
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("My Recipe App")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(Date(), style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
            .padding(24)
        }
        .background(Color.white)
        .frame(width: 400, height: 500)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

// Extension to convert View to UIImage
extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self.edgesIgnoringSafeArea(.all))
        let view = controller.view
        
        let targetSize = CGSize(width: 400, height: 500)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            view?.layer.render(in: context.cgContext)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        
        controller.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList,
            .postToFlickr,
            .postToVimeo,
            .openInIBooks
        ]
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
// Note: This app targets iOS 14.0+
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
