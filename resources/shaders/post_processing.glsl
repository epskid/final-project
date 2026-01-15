#version 430

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord)*colDiffuse*fragColor;
    finalColor = vec4(
        texelColor.r,
        // apply a blue(and green)-light filter to make colors warmer
        texelColor.g * 0.7,
        texelColor.b * 0.5,
        texelColor.a
    );
}
