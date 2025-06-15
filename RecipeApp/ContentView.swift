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

// MARK: - Weekly Planning View
struct WeeklyPlanningView: View {
    let selectedRecipeIDs: Set<UUID>
    let recipes: [Recipe]
    let onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
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
                                Text("\(recipe.servings) servings")
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
                        // TODO: Generate shopping list
                        dismiss()
                        onComplete()
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
