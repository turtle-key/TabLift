<script lang="ts">
  import { base } from '$app/paths';
  
  const blogPosts = [
    {
      slug: 'fix-cmd-tab-minimized-windows-macos',
      title: 'How to Fix ⌘+Tab on macOS So It Includes Minimized Windows',
      description: '⌘+Tab on macOS skips minimized windows by default. Here\'s why it happens and how to fix it permanently using a lightweight utility.',
      publishDate: '2024-01-29',
      readTime: '4 min read',
      color1: 'blue',
      color2: 'purple',
      category: 'Tutorial',
      keywords: ['cmd tab', 'macos', 'minimized windows', 'productivity', 'mac tips']
    },
    {
      slug: 'macos-minimized-windows-cmd-tab-simple-fix',
      title: 'macOS Skips Minimized Windows in ⌘+Tab – Here\'s a Simple Fix',
      description: 'macOS excludes minimized apps from the ⌘+Tab switcher by default. Learn how TabLift restores them automatically for a more consistent workflow.',
      publishDate: '2024-01-29',
      readTime: '3 min read',
      color1: 'purple',
      color2: 'pink',
      category: 'Solution',
      keywords: ['macos', 'app switcher', 'minimized apps', 'workflow', 'productivity']
    }
  ];
</script>

<svelte:head>
  <title>TabLift Blog – macOS Productivity Tips & App Switching Solutions</title>
  <meta name="description" content="Discover expert tips for improving macOS productivity, fixing ⌘+Tab behavior, and optimizing your Mac workflow with TabLift and other solutions." />
  <meta property="og:title" content="TabLift Blog – macOS Productivity Tips & Solutions" />
  <meta property="og:description" content="Expert guides on fixing macOS ⌘+Tab behavior, improving productivity, and optimizing your Mac workflow." />
  <meta property="og:url" content="https://tablift.dev/blog" />
  <meta name="twitter:title" content="TabLift Blog – macOS Productivity Tips" />
  <meta name="twitter:description" content="Expert guides on fixing macOS ⌘+Tab behavior and improving productivity." />
  <link rel="canonical" href="https://tablift.dev/blog" />
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Blog",
    "name": "TabLift Blog",
    "description": "Expert tips and solutions for macOS productivity and app switching",
    "url": "https://tablift.dev/blog",
    "publisher": {
      "@type": "Person",
      "name": "Mihai-Eduard Ghețu"
    }
  }
  </script>
</svelte:head>

<main class="min-h-screen bg-[#f7fafc] dark:bg-[#18181c] flex flex-col items-center font-sans pt-[90px]">
  <div class="w-full max-w-4xl mx-auto px-4">
    <!-- Blog Header -->
    <div class="text-center mb-16">
      <h1 class="text-5xl md:text-6xl font-extrabold text-gray-900 dark:text-gray-100 mb-4">
        TabLift Blog
      </h1>
      <p class="text-xl text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">
        Expert tips and solutions for improving macOS productivity, fixing app switching behavior, and optimizing your Mac workflow.
      </p>
    <!-- Blog Stats -->
      <div class="flex flex-wrap justify-center gap-6 mb-8 text-sm text-gray-600 dark:text-gray-400">
        <div class="flex items-center gap-2">
          <span class="material-symbols-rounded text-base text-blue-500">article</span>
          <span><strong>{blogPosts.length}</strong> Articles</span>
        </div>
        <div class="flex items-center gap-2">
          <span class="material-symbols-rounded text-base text-purple-500">update</span>
          <span>Updated <strong>July 2025</strong></span>
        </div>
      </div>
    </div>
    <!-- Blog Posts Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-16">
      {#each blogPosts as post}
        <article class="blog-post-card group relative bg-white dark:bg-gray-800 rounded-2xl overflow-hidden shadow-lg transition-all duration-500 cursor-pointer">
          <a href={`${base}/blog/${post.slug}`} class="block">
            <!-- Post Image -->
            <div class="relative h-48 overflow-hidden bg-gradient-to-br from-{post.color1}-500 to-{post.color2}-600">
              <div class="absolute inset-0 flex items-center justify-center">
                <div class="text-center text-white">
                  <div class="text-4xl mb-2">⌘</div>
                  <div class="text-sm font-medium">{post.category}</div>
                </div>
              </div>
              <div class="absolute top-4 left-4">
                <span class="inline-block px-3 py-1 text-xs font-semibold text-white bg-black bg-opacity-30 rounded-full backdrop-blur-sm">
                  {post.category}
                </span>
              </div>
            </div>

            <!-- Post Content -->
            <div class="p-6">
              <div class="flex items-center text-sm text-gray-500 dark:text-gray-400 mb-3">
                <time datetime={post.publishDate}>
                  {new Date(post.publishDate).toLocaleDateString('en-US', { 
                    year: 'numeric', 
                    month: 'long', 
                    day: 'numeric' 
                  })}
                </time>
                <span class="mx-2">•</span>
                <span>{post.readTime}</span>
              </div>

              <h2 class="text-xl font-bold text-gray-900 dark:text-gray-100 mb-3 group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors duration-300">
                {post.title}
              </h2>

              <p class="text-gray-600 dark:text-gray-300 mb-4 line-clamp-3">
                {post.description}
              </p>

              <!-- Keywords Tags -->
              <div class="flex flex-wrap gap-2 mb-4">
                {#each post.keywords.slice(0, 3) as keyword}
                  <span class="inline-block px-2 py-1 text-xs text-gray-600 dark:text-gray-400 bg-gray-100 dark:bg-gray-700 rounded">
                    {keyword}
                  </span>
                {/each}
              </div>

              <!-- Read More -->
              <div class="flex items-center text-blue-600 dark:text-blue-400 font-semibold group-hover:text-blue-700 dark:group-hover:text-blue-300 transition-colors duration-300">
                <span>Read Article</span>
                <svg class="w-4 h-4 ml-2 group-hover:translate-x-1 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
              </div>
            </div>
          </a>
        </article>
      {/each}
    </div>
  </div>
</main>

<style>
  .blog-post-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(59, 130, 246, 0.1), transparent);
    transition: left 0.6s;
    z-index: 1;
    pointer-events: none;
  }

  .blog-post-card:hover::before {
    left: 100%;
  }

  .blog-post-card:hover {
    transform: translateY(-8px);
    box-shadow: 0 20px 40px rgba(0,0,0,0.1);
  }

  :global(html.dark) .blog-post-card:hover {
    box-shadow: 0 20px 40px rgba(0,0,0,0.3);
  }

  .line-clamp-3 {
    display: -webkit-box;
    -webkit-line-clamp: 3;
    line-clamp: 3;  
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
</style>
