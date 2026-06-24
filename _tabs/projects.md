---
layout: page
icon: fas fa-diagram-project
order: 5
title: Projects
---

{% include lang.html %}

<div id="post-list" class="flex-grow-1 px-xl-1">
  {% for project in site.projects %}
    <article class="card-wrapper card">
      <a href="{{ project.url | relative_url }}" class="post-preview row g-0 flex-md-row-reverse">
        {% assign card_body_col = '12' %}
        {% if project.image %}
          <div class="col-md-5">
            <img src="{{ project.image | relative_url }}" alt="{{ project.title }}">
          </div>
          {% assign card_body_col = '7' %}
        {% endif %}
        <div class="col-md-{{ card_body_col }}">
          <div class="card-body d-flex flex-column">
            <h1 class="card-title my-2 mt-md-0">{{ project.title }}</h1>
            <div class="card-text content mt-0 mb-3">
              <p>{{ project.description }}</p>
            </div>
            <div class="post-meta flex-grow-1 d-flex align-items-end">
              <div class="me-auto">
                {% if project.tech %}
                  <i class="fas fa-code fa-fw me-1"></i>
                  <span class="categories">{{ project.tech | join: ', ' }}</span>
                {% endif %}
              </div>
            </div>
          </div>
        </div>
      </a>
    </article>
  {% endfor %}
</div>
