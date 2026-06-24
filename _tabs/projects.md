---
layout: page
icon: fas fa-diagram-project
order: 5
title: Projects
---

<style>
  .project-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 1.25rem;
    margin-top: 1.5rem;
  }
  .project-card {
    border: 1px solid var(--card-border-color, #d0d0d0);
    border-radius: 10px;
    padding: 1rem 1.2rem;
    background: var(--card-bg, transparent);
  }
  .project-card img { width: 100%; border-radius: 6px; margin-bottom: .6rem; }
  .project-card h3 { margin: .2rem 0 .4rem; }
  .project-card .tech { list-style: none; padding: 0; display: flex; flex-wrap: wrap; gap: .35rem; margin: .6rem 0; }
  .project-card .tech li { font-size: .72rem; padding: .12rem .5rem; border-radius: 999px; background: rgba(127,127,127,.18); }
  .project-card .links a { margin-right: .8rem; font-weight: 600; }
</style>

<div class="project-grid">
{% for project in site.projects %}
  <article class="project-card">
    {% if project.image %}<img src="{{ project.image | relative_url }}" alt="{{ project.title }}">{% endif %}
    <h3>{{ project.title }}</h3>
    <p>{{ project.description }}</p>
    {% if project.tech %}
    <ul class="tech">
      {% for t in project.tech %}<li>{{ t }}</li>{% endfor %}
    </ul>
    {% endif %}
    <p class="links">
      {% if project.url %}<a href="{{ project.url }}">Details</a>{% endif %}
      {% if project.source %}<a href="{{ project.source }}">Source</a>{% endif %}
      {% if project.demo %}<a href="{{ project.demo }}">Demo</a>{% endif %}
    </p>
  </article>
{% endfor %}
</div>
