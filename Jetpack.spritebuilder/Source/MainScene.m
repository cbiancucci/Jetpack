//
//  MainScene.m
//  PROJECTNAME
//
//  Created by Viktor on 10/10/13.
//  Copyright (c) 2013 Apportable. All rights reserved.
//

#import "MainScene.h"
#import "Character.h"
#import "Rock.h"
#import "Rocket.h"
#import "Bullet.h"
#import "Explosion.h"

static const CGFloat cameraScrollSpeed = 80.f;
static const CGFloat characterScrollSpeed = 280.f;
static const CGFloat firstRockXPosition = 280.f;
static const CGFloat firstRockYPosition = 100.f;
static const CGFloat distanceBetweenRocks = 50.f;

typedef NS_ENUM (NSInteger, DrawingOrder) {
	DrawingOrderBackground,
	DrawingOrderRock,
	DrawingOrderCharacter,
	DrawingOrderBullet,
	DrawingOrderParticles,
	DrawingOrderText
};

@implementation MainScene {
	double distance;

	CGSize size;

	//PhysicsNode
	CCPhysicsNode *_physicsNode;

	// Character
	Character *character;

	// Texts
	CCLabelTTF *distanceText;

	// Background
	CCNode *_background1;
	CCNode *_background2;
	CCNode *_spike;
	NSArray *_backgrounds;

	// Floor
	CCNode *_floors;

	// Roof
	CCNode *_roof1;
	CCNode *_roof2;
	NSArray *_roofs;

	NSTimeInterval _sinceTouch;
	NSTimeInterval _sinceUranium;
	NSTimeInterval _sinceShoot;
	NSTimeInterval _sinceBullet;

	// Rocks
	NSMutableArray *_rocks;

	// Weapons
	NSMutableArray *bullets;

	// Difficulties
	Rocket *rocket;
}

- (void)didLoadFromCCB {
	size  = [CCDirector sharedDirector].viewSize;

	// set this class as delegate
	_physicsNode.collisionDelegate = self;

	// Texts
	[self loadTextSettings];

	// Context
	[self loadContextInitialSettings];

	// Uranium Rocks
	[self loadRocksInitialSettings];

	// Character
	[self loadCharacterInitialSettings];

	// Difficulties
	[self loadDifficultiesSettings];

	// Music
	[self loadMusicSettings];

	self.userInteractionEnabled = YES;

	_physicsNode.debugDraw = YES;
}

- (void)loadTextSettings {
	//hei(TO LENOVO LE Phone)
	distanceText = [CCLabelTTF labelWithString:@"000" fontName:@"heiTOLENOVOLEPhone.ttf" fontSize:20];
	distanceText.outlineColor = [CCColor blackColor];
	distanceText.outlineWidth = 2.0f;
	distanceText.zOrder = DrawingOrderText;
	[distanceText setPosition:ccp(30.f, 300.f)];
	[self addChild:distanceText];
}

- (void)loadContextInitialSettings {
	distance = 0;
	_backgrounds = @[_background1, _background2];
	_roofs = @[_roof1, _roof2];
	_spike.physicsBody.sensor = YES;
}

- (void)loadCharacterInitialSettings {
	character = (Character *)[_physicsNode getChildByName:@"Character" recursively:YES];
	character.zOrder = DrawingOrderCharacter;
	character.hasAdrenaline = NO;
	[character stop];
	[character startWalking];
}

- (void)loadRocksInitialSettings {
	_rocks = [NSMutableArray array];
	[self spawnNewRock];
	[self spawnNewRock];
	[self spawnNewRock];
}

- (void)loadDifficultiesSettings {
	rocket = (Rocket *)[CCBReader load:@"RocketExplosion"];
	rocket.zOrder = DrawingOrderParticles;
	[rocket setPosition:ccp(1000.f, 70.f)];
	[_physicsNode addChild:rocket];
}

- (void)loadMusicSettings {
	OALSimpleAudio *audio = [OALSimpleAudio sharedInstance];
	[audio playEffect:@"Level.mp3"];
}

- (void)update:(CCTime)delta {
	// Update rocket position.
	if (rocket) {
		rocket.physicsBody.velocity = CGPointMake(-50, 0);
	}

	// Update and destroy off screen bullets.
	if (bullets && [bullets count] > 0) {
		[self updateBullets:delta];
	}

	// Update character position.
	if ([character hasAdrenaline]) {
		character.position = ccp(character.position.x + delta * characterScrollSpeed, character.position.y);
		_physicsNode.position = ccp(_physicsNode.position.x - (characterScrollSpeed * delta), _physicsNode.position.y);

		distance += 0.5f;
	}
	else {
		character.position = ccp(character.position.x + delta * cameraScrollSpeed, character.position.y);
		_physicsNode.position = ccp(_physicsNode.position.x - (cameraScrollSpeed * delta), _physicsNode.position.y);

		distance += 0.1f;
	}

	// Update character state.
	_sinceBullet += delta;
	if ([character isShooting] && _sinceBullet > 0.4f) {
		_sinceBullet = 0;
		[self createBullet];
	}
	_sinceUranium += delta;
	if (_sinceUranium > 2.0f) {
		character.hasAdrenaline = NO;
	}

	if ([character isRunning] && ![character hasAdrenaline]) {
		[character startWalking];
	}

	_sinceShoot  += delta;
	if ([character isShooting] && _sinceShoot > 1.0f) {
		[character stopShooting];
	}

	// Update distance text.
	[distanceText setString:[NSString stringWithFormat:@"%i%@", (int)distance, @"M"]];

	[self loopBackground];
}

- (void)updateBullets:(CCTime)delta {
	NSMutableArray *removeBullets = [[NSMutableArray alloc] init];
	for (Bullet *bullet in bullets) {
		bullet.position = ccp(bullet.position.x + (delta * 10 * cameraScrollSpeed), bullet.position.y);

		CGPoint bulletWorldPosition = [_physicsNode convertToWorldSpace:bullet.position];
		if (bulletWorldPosition.x > size.width) {
			[removeBullets addObject:bullet];
		}
	}

	if ([removeBullets count] > 0) {
		[self destroyBullets:removeBullets];
	}
}

- (void)destroyBullets:(NSMutableArray *)removeBullets {
	for (Bullet *bullet in removeBullets) {
		[bullet removeFromParentAndCleanup:YES];
		[bullets removeObject:bullet];
	}
}

- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
	CGPoint touchLocation = [touch locationInView:[touch view]];

	if ((touchLocation.x > 525 && touchLocation.x < 560) && (touchLocation.y > 10 && touchLocation.y < 40)) {
		if ([CCDirector sharedDirector].isPaused) {
			[[CCDirector sharedDirector] resume];
		}
		else {
			[[CCDirector sharedDirector] pause];
		}
	}
	else if (![CCDirector sharedDirector].isPaused) {
		if (touchLocation.x < 300) {
			if (![character isJumping]) {
				[character startJumping];
			}
		}
		else {
			[character startShooting];
			_sinceShoot = 0.f;
			_sinceBullet = 0.f;
			[self createBullet];
		}
	}
}

- (void)loopBackground {
	// loop the background
	for (CCNode *background in _backgrounds) {
		// get the world position of the background
		CGPoint groundWorldPosition = [_physicsNode convertToWorldSpace:background.position];
		// get the screen position of the background
		CGPoint groundScreenPosition = [self convertToNodeSpace:groundWorldPosition];
		// if the left corner is one complete width off the screen, move it to the right
		if (groundScreenPosition.x <= (-1 * background.contentSize.width)) {
			background.position = ccp(background.position.x + 2 * background.contentSize.width, background.position.y);
			background.zOrder = DrawingOrderBackground;
		}
	}

	for (CCNode *floor in _floors.children) {
		CGPoint groundWorldPosition = [_physicsNode convertToWorldSpace:floor.position];
		CGPoint groundScreenPosition = [self convertToNodeSpace:groundWorldPosition];
		if (groundScreenPosition.x <= (-1 * floor.contentSize.width)) {
			floor.position = ccp(floor.position.x + 2 * (floor.contentSize.width - 2), floor.position.y);
			floor.zOrder = DrawingOrderBackground;
		}
	}

	for (CCNode *roof in _roofs) {
		CGPoint groundWorldPosition = [_physicsNode convertToWorldSpace:roof.position];
		CGPoint groundScreenPosition = [self convertToNodeSpace:groundWorldPosition];
		if (groundScreenPosition.x <= (-1 * roof.contentSize.width)) {
			roof.position = ccp(roof.position.x + 2 * roof.contentSize.width, roof.position.y);
			roof.zOrder = DrawingOrderBackground;
		}
	}
}

- (void)spawnNewRock {
	CCNode *previousRock = [_rocks lastObject];
	CGFloat previousRockXPosition = previousRock.position.x;
	CGFloat previousRockYPosition = previousRock.position.y;

	if (!previousRock) {
		// this is the first obstacle
		previousRockXPosition = firstRockXPosition;
		previousRockYPosition = firstRockYPosition;
	}

	Rock *rock = (Rock *)[CCBReader load:@"Uranium"];
	rock.position = ccp(previousRockXPosition + distanceBetweenRocks, previousRockYPosition);
	rock.zOrder = DrawingOrderCharacter;

	[_physicsNode addChild:rock];
	[_rocks addObject:rock];
}

- (void)createBullet {
	if (!bullets) {
		bullets = [[NSMutableArray alloc] init];
	}

	Bullet *bullet = (Bullet *)[CCBReader load:@"Bullet"];
	[bullet setPosition:ccp(character.position.x + 30, character.position.y - 8)];
	bullet.zOrder = DrawingOrderBullet;
	[_physicsNode addChild:bullet];
	[bullets addObject:bullet];
}

// >>> Collisions

// Uranium rocks
- (BOOL)ccPhysicsCollisionBegin:(CCPhysicsCollisionPair *)pair character:(Character *)characterCollision rock:(Rock *)rock {
	NSLog(@"Character and rock collision");
	rock.visible = NO;
	[rock removeFromParentAndCleanup:YES];
	[_rocks removeObject:rock];

	_sinceUranium = 0.f;
	character.hasAdrenaline = YES;
	[character startRunning];
	return YES;
}

// Play blood particle.
- (BOOL)ccPhysicsCollisionBegin:(CCPhysicsCollisionPair *)pair character:(Character *)characterCollision spike:(CCNode *)spike {
	NSLog(@"Character and spike collision");
	CCParticleSystem *blood = (CCParticleSystem *)[CCBReader load:@"Blood"];
	blood.autoRemoveOnFinish = YES;
	blood.position = character.position;
	blood.scaleX = 0.75f;
	blood.scaleY = 0.75f;
	blood.zOrder = DrawingOrderParticles;
	[_physicsNode addChild:blood];
	//[character die];

	return YES;
}

// Stop jumping.
- (BOOL)ccPhysicsCollisionBegin:(CCPhysicsCollisionPair *)pair character:(Character *)characterCollision floor:(CCNode *)floor {
	NSLog(@"Character and floor collision");
	if ([character isJumping]) {
		[character startWalking];
	}
	return YES;
}

// Explode and die.
- (BOOL)ccPhysicsCollisionBegin:(CCPhysicsCollisionPair *)pair character:(Character *)characterCollision rocket:(Rocket *)rocketCollision {
	NSLog(@"Character and rocket collision");
	Explosion *explosion = (Explosion *)[CCBReader load:@"Explosion"];
	[rocket addChild:explosion];
	[rocket explode];
	explosion.position = ccp(0, 0);

	[character die];

	return YES;
}

// Explode and die.
- (BOOL)ccPhysicsCollisionBegin:(CCPhysicsCollisionPair *)pair bullet:(Bullet *)bulletCollision rocket:(Rocket *)rocketCollision {
	NSLog(@"Bullet and rocket collision");
	[rocket explode];
	//[character die];

	return YES;
}

@end
